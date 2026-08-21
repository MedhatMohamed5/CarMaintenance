import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/platform/image_source_picker.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../../core/theme/app_theme.dart';
import 'vehicle_image.dart';

class VehiclePhotoField extends ConsumerStatefulWidget {
  const VehiclePhotoField({
    super.key,
    required this.imageBase64,
    required this.accent,
    required this.onChanged,
  });

  final String? imageBase64;
  final Color accent;
  final ValueChanged<String?> onChanged;

  @override
  ConsumerState<VehiclePhotoField> createState() => _VehiclePhotoFieldState();
}

class _VehiclePhotoFieldState extends ConsumerState<VehiclePhotoField> {
  bool _busy = false;

  Future<void> _pick(VehicleImageSource source) async {
    setState(() => _busy = true);
    final encoded = await ref
        .read(imagePickerServiceProvider)
        .pickAsBase64(source);
    if (!mounted) return;
    setState(() => _busy = false);

    if (encoded == null) return;
    widget.onChanged(encoded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final picker = ref.read(imagePickerServiceProvider);
    final image = VehicleImageResolver.from(imageBase64: widget.imageBase64);
    final hasImage = image != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.raw('vehiclePhoto'),
            style: context.text.labelMedium?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null)
                    Image(
                      image: image,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) =>
                          _Placeholder(accent: widget.accent),
                    )
                  else
                    _Placeholder(accent: widget.accent),
                  if (hasImage)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  if (_busy)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    ),
                  if (hasImage && !_busy)
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: _RoundAction(
                        icon: Icons.delete_outline_rounded,
                        onTap: () => widget.onChanged(null),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final source in picker.availableSources) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(source),
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
    VehicleImageSource.camera => 'takePhoto',
    VehicleImageSource.gallery => 'chooseFromGallery',
    VehicleImageSource.files => 'uploadImage',
  };
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: 0.16),
              context.tokens.surfaceHigh,
            ),
            context.tokens.surfaceHigh,
          ],
        ),
        border: Border.all(color: context.tokens.border),
      ),
      child: Center(
        child: Icon(
          Icons.directions_car_filled_rounded,
          size: 46,
          color: accent.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(7),
          child: Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
