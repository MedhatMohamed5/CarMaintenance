import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../platform/platform_providers.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

/// A count of attached invoices, and nothing else.
///
/// **Deliberately incapable of rendering one.** This is what list rows and
/// summaries get: it reads `length` and never touches the encoded bytes, so a
/// screen of forty expenses does no base64 decoding and uploads no textures for
/// receipts nobody has asked to see. Opening [InvoiceViewer] is the only path
/// to the images, and it is a tap.
///
/// One honest limit: the encoded strings ride along with the record itself,
/// because that is where they are stored. What this avoids is the expensive
/// half — decoding and rasterising. Keeping the bytes themselves out of a list
/// query would mean moving attachments into their own documents, which is a
/// storage change, not a widget one.
class InvoiceCountChip extends StatelessWidget {
  const InvoiceCountChip({
    super.key,
    required this.attachments,
    required this.color,
  });

  final List<String> attachments;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Tooltip(
      message: context.l10n.raw('invoiceAttachment'),
      child: Material(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => InvoiceViewer.show(context, attachments: attachments),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  '${attachments.length}',
                  style: context.text.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The attached invoices at full size, one per page, decoded on arrival.
///
/// **Nothing is decoded until its page is built.** `PageView.builder` only
/// builds the page in view and its immediate neighbour, so opening four
/// receipts costs one decode, not four — and the cache below means swiping back
/// does not pay for it twice.
///
/// A receipt is read rather than glanced at, so it gets pan and zoom, and
/// swiping between pages beats closing and reopening to compare two.
class InvoiceViewer extends ConsumerStatefulWidget {
  const InvoiceViewer({
    super.key,
    required this.attachments,
    this.initialPage = 0,
  });

  /// Base64-encoded, exactly as stored on the record. Decoding happens here.
  final List<String> attachments;

  final int initialPage;

  static Future<void> show(
    BuildContext context, {
    required List<String> attachments,
    int initialPage = 0,
  }) {
    if (attachments.isEmpty) return Future<void>.value();
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            InvoiceViewer(attachments: attachments, initialPage: initialPage),
      ),
    );
  }

  @override
  ConsumerState<InvoiceViewer> createState() => _InvoiceViewerState();
}

class _InvoiceViewerState extends ConsumerState<InvoiceViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage,
  );
  late int _page = widget.initialPage;

  /// Decoded pages, kept so a swipe back does not decode again. Bounded by the
  /// attachment cap on the record, so it cannot grow without limit.
  final _decoded = <int, Uint8List?>{};

  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Null for an entry that will not decode — a row from an older build, or a
  /// partial sync. The page shows a placeholder rather than throwing.
  Uint8List? _bytesFor(int index) => _decoded.putIfAbsent(index, () {
    final encoded = widget.attachments[index];
    if (encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      return null;
    }
  });

  Future<void> _download() async {
    final bytes = _bytesFor(_page);
    if (bytes == null || _saving) return;

    setState(() => _saving = true);
    final l10n = context.l10n;
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final format = _ImageFormat.of(bytes);

    try {
      final saved = await ref
          .read(fileSaverProvider)
          .save(
            fileName: 'invoice-$stamp-${_page + 1}${format.extension}',
            bytes: bytes,
            mimeType: format.mimeType,
          );
      if (!mounted) return;
      showAppSnack(
        context,
        saved.downloaded
            ? l10n.raw('exportDownloaded')
            : '${l10n.raw('exportSavedTo')} ${saved.path ?? saved.fileName}',
        icon: Icons.download_done_rounded,
      );
    } on Object {
      if (!mounted) return;
      showAppSnack(
        context,
        l10n.somethingWentWrong,
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final multiple = widget.attachments.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          multiple
              ? '${_page + 1} / ${widget.attachments.length}'
              : l10n.raw('invoiceAttachment'),
        ),
        actions: [
          IconButton(
            tooltip: l10n.raw('invoiceDownload'),
            onPressed: _saving ? null : _download,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.attachments.length,
        onPageChanged: (index) => setState(() => _page = index),
        itemBuilder: (context, index) {
          final bytes = _bytesFor(index);
          if (bytes == null) {
            return Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            );
          }
          return InteractiveViewer(
            maxScale: 5,
            child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
          );
        },
      ),
    );
  }
}

/// What the bytes actually are, read from their own header.
///
/// **Sniffed rather than assumed.** The camera path re-encodes to JPEG, but the
/// file path on web hands over whatever was chosen, and saving a PNG as `.jpg`
/// gives the driver a file their viewer may refuse to open.
enum _ImageFormat {
  jpeg('.jpg', 'image/jpeg'),
  png('.png', 'image/png'),
  webp('.webp', 'image/webp'),
  gif('.gif', 'image/gif'),
  pdf('.pdf', 'application/pdf');

  const _ImageFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;

  static _ImageFormat of(Uint8List bytes) {
    bool startsWith(List<int> magic) {
      if (bytes.length < magic.length) return false;
      for (var i = 0; i < magic.length; i++) {
        if (bytes[i] != magic[i]) return false;
      }
      return true;
    }

    if (startsWith([0x89, 0x50, 0x4E, 0x47])) return _ImageFormat.png;
    if (startsWith([0x47, 0x49, 0x46, 0x38])) return _ImageFormat.gif;
    if (startsWith([0x25, 0x50, 0x44, 0x46])) return _ImageFormat.pdf;
    // "RIFF" then "WEBP" four bytes later.
    if (startsWith([0x52, 0x49, 0x46, 0x46]) &&
        bytes.length >= 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return _ImageFormat.webp;
    }
    return _ImageFormat.jpeg;
  }
}
