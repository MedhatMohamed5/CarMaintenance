import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../platform/image_source_picker.dart';
import '../platform/platform_providers.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';
import 'invoice_viewer.dart';

/// Picks, shows and removes the invoices photographed for a service or an
/// expense.
///
/// **One widget for both, because it is one job.** A receipt attached to a
/// service and a receipt attached to an expense differ in nothing a user can
/// see, and two copies would drift the first time either was touched.
///
/// **The caps are not arbitrary and they are not decoration.** Attachments are
/// stored inline on the record, so every one of them counts against Firestore's
/// 1 MB document limit — and base64 inflates the raw bytes by about a third on
/// the way in. A single photograph could be allowed to fill most of that
/// budget; several cannot. [maxAttachments] and [_maxPerFileBytes] together
/// keep the worst case inside the limit, and the field says so rather than
/// letting a save fail somewhere the driver cannot see.
class InvoiceAttachmentField extends ConsumerStatefulWidget {
  const InvoiceAttachmentField({
    super.key,
    required this.attachments,
    required this.accent,
    required this.onChanged,
  });

  /// Everything attached so far. Empty is the normal starting state.
  final List<String> attachments;

  final Color accent;

  /// Called with the full new list whenever one is added or removed.
  final ValueChanged<List<String>> onChanged;

  /// Enough for parts and labour billed separately, plus a spare. Past this the
  /// record stops fitting its own storage.
  static const int maxAttachments = 4;

  /// Raw bytes allowed per file, before base64 inflates them.
  ///
  /// Four of these encode to roughly 950 KB, which is what leaves the rest of
  /// the record room inside the 1 MB document.
  static const int _maxPerFileBytes = 175 * 1024;

  @override
  ConsumerState<InvoiceAttachmentField> createState() =>
      _InvoiceAttachmentFieldState();
}

class _InvoiceAttachmentFieldState
    extends ConsumerState<InvoiceAttachmentField> {
  bool _busy = false;

  int get _remaining =>
      InvoiceAttachmentField.maxAttachments - widget.attachments.length;

  /// Thumbnails, decoded when the list changes rather than on every build.
  ///
  /// **The form rebuilds on every keystroke and every category tap.** Decoding
  /// four receipts inside `build` meant paying for all of them again each time,
  /// for images that had not changed. Tolerant of a row written by an older
  /// build or truncated by a partial sync: an entry that will not decode is
  /// dropped from the strip instead of throwing inside a form the driver is
  /// halfway through.
  late List<({int index, Uint8List bytes})> _thumbnails;

  @override
  void initState() {
    super.initState();
    _thumbnails = _decodeAll();
  }

  @override
  void didUpdateWidget(InvoiceAttachmentField old) {
    super.didUpdateWidget(old);
    if (!identical(old.attachments, widget.attachments)) {
      _thumbnails = _decodeAll();
    }
  }

  List<({int index, Uint8List bytes})> _decodeAll() => [
    for (var i = 0; i < widget.attachments.length; i++)
      if (_decode(widget.attachments[i]) case final bytes?)
        (index: i, bytes: bytes),
  ];

  static Uint8List? _decode(String encoded) {
    if (encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      return null;
    }
  }

  void _remove(int index) {
    final next = [...widget.attachments]..removeAt(index);
    widget.onChanged(List<String>.unmodifiable(next));
  }

  void _append(List<String> picked, {int rejectedForSize = 0}) {
    final room = _remaining;
    final accepted = picked.take(room).toList();
    final overflow = picked.length - accepted.length;

    if (accepted.isNotEmpty) {
      widget.onChanged(
        List<String>.unmodifiable([...widget.attachments, ...accepted]),
      );
    }

    if (!mounted) return;
    // **Say what was refused.** Silently keeping three of five leaves the
    // driver believing every receipt is on file, and they only find out when
    // they need one.
    if (rejectedForSize > 0) {
      showAppSnack(
        context,
        context.l10n.fmt('invoiceTooLarge', {'n': rejectedForSize}),
        icon: Icons.warning_amber_rounded,
      );
    } else if (overflow > 0) {
      showAppSnack(
        context,
        context.l10n.fmt('invoiceLimit', {
          'n': InvoiceAttachmentField.maxAttachments,
        }),
        icon: Icons.warning_amber_rounded,
      );
    }
  }

  Future<void> _pickOne(VehicleImageSource source) async {
    setState(() => _busy = true);
    final encoded = await ref
        .read(imagePickerServiceProvider)
        .pickAsBase64(
          source,
          maxBytes: InvoiceAttachmentField._maxPerFileBytes,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    // Null is a dismissed picker or a file over the cap, and the two are
    // indistinguishable from here. A dismissal is the common one and deserves
    // silence, so the size message lives on the multi-pick path where the
    // count makes it unambiguous.
    if (encoded == null) return;
    _append([encoded]);
  }

  Future<void> _pickMany() async {
    setState(() => _busy = true);
    final result = await ref
        .read(imagePickerServiceProvider)
        .pickMultipleAsBase64(
          maxBytes: InvoiceAttachmentField._maxPerFileBytes,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.encoded.isEmpty && result.rejected == 0) return;
    _append(result.encoded, rejectedForSize: result.rejected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final picker = ref.read(imagePickerServiceProvider);
    final decoded = _thumbnails;
    final full = _remaining <= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.raw('invoiceAttachment'),
                  style: context.text.labelMedium?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ),
              if (decoded.isNotEmpty)
                Text(
                  '${decoded.length}/${InvoiceAttachmentField.maxAttachments}',
                  style: context.text.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (decoded.isEmpty)
            _Empty(accent: widget.accent, busy: _busy)
          else
            _Gallery(
              items: decoded,
              busy: _busy,
              onOpen: (start) => InvoiceViewer.show(
                context,
                attachments: widget.attachments,
                initialPage: decoded[start].index,
              ),
              onRemove: _remove,
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final source in picker.availableSources) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy || full
                        ? null
                        : () => source == VehicleImageSource.camera
                              ? _pickOne(source)
                              : _pickMany(),
                    icon: Icon(_iconFor(source), size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.raw(_labelKeyFor(source))),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: widget.accent,
                      side: BorderSide(
                        color: widget.accent.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
                if (source != picker.availableSources.last)
                  const SizedBox(width: 10),
              ],
            ],
          ),
          if (full) ...[
            const SizedBox(height: 6),
            Text(
              l10n.fmt('invoiceLimit', {
                'n': InvoiceAttachmentField.maxAttachments,
              }),
              style: context.text.labelSmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(VehicleImageSource source) => switch (source) {
    VehicleImageSource.camera => Icons.photo_camera_rounded,
    VehicleImageSource.gallery => Icons.photo_library_rounded,
    VehicleImageSource.files => Icons.upload_file_rounded,
  };

  static String _labelKeyFor(VehicleImageSource source) => switch (source) {
    VehicleImageSource.camera => 'scanInvoice',
    VehicleImageSource.gallery => 'chooseFromGallery',
    VehicleImageSource.files => 'uploadImage',
  };
}

/// The attached receipts as a horizontal strip.
///
/// Horizontal rather than a grid: the form is already a tall scrolling column
/// inside a sheet, and a grid that grows downward pushes the save button
/// further away with every attachment.
class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.items,
    required this.busy,
    required this.onOpen,
    required this.onRemove,
  });

  final List<({int index, Uint8List bytes})> items;
  final bool busy;
  final ValueChanged<int> onOpen;
  final ValueChanged<int> onRemove;

  static const double _size = 104;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, position) {
          final item = items[position];
          return SizedBox(
            width: _size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: context.tokens.surfaceHigh,
                    // `contain`, not `cover`: a receipt cropped to fill the
                    // square is a receipt with its total cut off.
                    child: Image.memory(
                      item.bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: busy ? null : () => onOpen(position),
                  ),
                ),
                if (!busy)
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: _RoundAction(
                      icon: Icons.close_rounded,
                      tooltip: context.l10n.delete,
                      onTap: () => onRemove(item.index),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.accent, required this.busy});

  final Color accent;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: context.tokens.surfaceHigh,
        border: Border.all(color: context.tokens.border),
      ),
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: context.tokens.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.raw('invoiceNone'),
                  style: context.text.bodySmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
            ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
