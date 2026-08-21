import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/platform/local_file_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/vehicle_paint.dart';

/// Single resolution point for vehicle artwork. Order of preference:
/// inline bytes → network URL → local file path. Anything unresolvable
/// returns null so callers fall through to the styled placeholder.
class VehicleImageResolver {
  const VehicleImageResolver._();

  static ImageProvider? of(Vehicle vehicle) =>
      from(imageBase64: vehicle.imageBase64, imageUrl: vehicle.imageUrl);

  static ImageProvider? from({String? imageBase64, String? imageUrl}) {
    final bytes = decodeBytes(imageBase64);
    if (bytes != null) return MemoryImage(bytes);

    final source = imageUrl?.trim();
    if (source == null || source.isEmpty) return null;

    if (source.startsWith('http://') || source.startsWith('https://')) {
      return NetworkImage(source);
    }
    return localFileImage(source);
  }

  static Uint8List? decodeBytes(String? base64Data) {
    if (base64Data == null || base64Data.isEmpty) return null;
    try {
      return base64Decode(base64Data);
    } catch (_) {
      return null;
    }
  }
}

/// Circular vehicle thumbnail with a gradient fallback.
class VehicleAvatar extends StatelessWidget {
  const VehicleAvatar({
    super.key,
    this.vehicle,
    this.imageBase64,
    this.imageUrl,
    required this.accent,
    this.size = 46,
    this.showRing = true,
  });

  VehicleAvatar.of(
    Vehicle this.vehicle, {
    super.key,
    this.size = 46,
    this.showRing = true,
  }) : imageBase64 = vehicle.imageBase64,
       imageUrl = vehicle.imageUrl,
       accent = VehiclePaint.accentFor(vehicle.colorValue);

  final Vehicle? vehicle;
  final String? imageBase64;
  final String? imageUrl;
  final Color accent;
  final double size;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final image = VehicleImageResolver.from(
      imageBase64: imageBase64,
      imageUrl: imageUrl,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: image == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.28),
                  accent.withValues(alpha: 0.10),
                ],
              )
            : null,
        border: showRing
            ? Border.all(color: accent.withValues(alpha: 0.45), width: 1.5)
            : null,
        boxShadow: showRing
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? _Glyph(accent: accent, size: size * 0.5)
          : Image(
              image: image,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) =>
                  _Glyph(accent: accent, size: size * 0.5),
            ),
    );
  }
}

/// Wide vehicle banner used as a card background or a details header.
class VehicleImageHeader extends StatelessWidget {
  const VehicleImageHeader({
    super.key,
    this.vehicle,
    this.imageBase64,
    this.imageUrl,
    required this.accent,
    this.height = 168,
    this.borderRadius = 22,
    this.overlay = true,
    this.child,
  });

  VehicleImageHeader.of(
    Vehicle this.vehicle, {
    super.key,
    this.height = 168,
    this.borderRadius = 22,
    this.overlay = true,
    this.child,
  }) : imageBase64 = vehicle.imageBase64,
       imageUrl = vehicle.imageUrl,
       accent = VehiclePaint.accentFor(vehicle.colorValue);

  final Vehicle? vehicle;
  final String? imageBase64;
  final String? imageUrl;
  final Color accent;
  final double height;
  final double borderRadius;
  final bool overlay;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final image = VehicleImageResolver.from(
      imageBase64: imageBase64,
      imageUrl: imageUrl,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image == null)
              _PlaceholderPanel(accent: accent)
            else
              Image(
                image: image,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _PlaceholderPanel(accent: accent),
              ),
            if (overlay)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: image == null ? 0 : 0.10),
                      Colors.black.withValues(alpha: image == null ? 0 : 0.55),
                    ],
                  ),
                ),
              ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

/// Card backdrop: renders artwork behind existing card content, tinted so
/// foreground text stays legible. Falls through to [child] when unset.
class VehicleImageBackdrop extends StatelessWidget {
  const VehicleImageBackdrop({
    super.key,
    required this.imageBase64,
    required this.imageUrl,
    required this.accent,
    required this.child,
    this.borderRadius = 22,
  });

  final String? imageBase64;
  final String? imageUrl;
  final Color accent;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = VehicleImageResolver.from(
      imageBase64: imageBase64,
      imageUrl: imageUrl,
    );
    if (image == null) return child;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image(
              image: image,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topEnd,
                  end: AlignmentDirectional.bottomStart,
                  colors: [
                    context.colors.surface.withValues(alpha: 0.72),
                    context.colors.surface.withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.accent, required this.size});

  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.directions_car_filled_rounded,
    size: size.roundToDouble(),
    color: accent,
  );
}

class _PlaceholderPanel extends StatelessWidget {
  const _PlaceholderPanel({required this.accent});

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
              accent.withValues(alpha: 0.18),
              context.tokens.surfaceHigh,
            ),
            context.tokens.surfaceHigh,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.directions_car_filled_rounded,
          size: 52,
          color: accent.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
