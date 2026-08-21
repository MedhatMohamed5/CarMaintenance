import 'dart:math' as math;

import 'package:flutter/material.dart';

class VehicleCareLogo extends StatelessWidget {
  const VehicleCareLogo({super.key, this.size = 96, this.showBackground = true});

  final double size;
  final bool showBackground;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: VehicleCareLogoPainter(showBackground: showBackground),
      isComplex: true,
    ),
  );
}

class VehicleCareLogoPainter extends CustomPainter {
  const VehicleCareLogoPainter({this.showBackground = true});

  final bool showBackground;

  static const Color charcoalHigh = Color(0xFF1C2230);
  static const Color charcoalDeep = Color(0xFF0A0E14);
  static const Color steel = Color(0xFF8A99AD);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color cyanBright = Color(0xFF7DE9FB);
  static const Color electricBlue = Color(0xFF3B82F6);

  static const double _gaugeStart = math.pi;
  static const double _gaugeSweep = math.pi;
  static const double _gaugeFill = 0.64;
  static const double _gaugeCentreY = 0.425;
  static const double _gaugeRadius = 0.125;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (showBackground) _paintBadge(canvas, s);
    _paintShield(canvas, s);
    _paintGauge(canvas, s);
    _paintVehicle(canvas, s);
  }

  void _paintBadge(Canvas canvas, double s) {
    final rect = Rect.fromLTWH(0, 0, s, s);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(s * 0.2237)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [charcoalHigh, charcoalDeep],
        ).createShader(rect),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(s * 0.2237)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    final glowCenter = Offset(s * 0.30, s * 0.20);
    canvas.drawCircle(
      glowCenter,
      s * 0.46,
      Paint()
        ..shader = RadialGradient(
          colors: [cyan.withValues(alpha: 0.20), Colors.transparent],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: s * 0.46)),
    );
  }

  void _paintGauge(Canvas canvas, double s) {
    final centre = Offset(s * 0.5, s * _gaugeCentreY);
    final rect = Rect.fromCircle(center: centre, radius: s * _gaugeRadius);
    final stroke = s * 0.038;

    canvas.drawArc(
      rect,
      _gaugeStart,
      _gaugeSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = steel.withValues(alpha: 0.30),
    );

    canvas.drawArc(
      rect,
      _gaugeStart,
      _gaugeSweep * _gaugeFill,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [electricBlue, cyan, cyanBright],
        ).createShader(rect),
    );

    final headAngle = _gaugeStart + _gaugeSweep * _gaugeFill;
    canvas.drawLine(
      centre + _polar(headAngle, s * 0.030),
      centre + _polar(headAngle, s * (_gaugeRadius - 0.034)),
      Paint()
        ..strokeWidth = s * 0.022
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
    canvas.drawCircle(centre, s * 0.026, Paint()..color = Colors.white);
    canvas.drawCircle(centre, s * 0.012, Paint()..color = charcoalDeep);
  }

  void _paintShield(Canvas canvas, double s) {
    final shield = Path()
      ..moveTo(s * 0.500, s * 0.150)
      ..lineTo(s * 0.746, s * 0.246)
      ..lineTo(s * 0.746, s * 0.516)
      ..quadraticBezierTo(s * 0.746, s * 0.724, s * 0.500, s * 0.836)
      ..quadraticBezierTo(s * 0.254, s * 0.724, s * 0.254, s * 0.516)
      ..lineTo(s * 0.254, s * 0.246)
      ..close();

    canvas.drawPath(
      shield,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            charcoalHigh.withValues(alpha: 0.96),
            charcoalDeep.withValues(alpha: 0.99),
          ],
        ).createShader(shield.getBounds()),
    );

    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.026
        ..strokeJoin = StrokeJoin.round
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cyanBright, cyan, electricBlue],
        ).createShader(shield.getBounds()),
    );
  }

  void _paintVehicle(Canvas canvas, double s) {
    canvas
      ..save()
      ..translate(s * 0.5, s * 0.615)
      ..scale(0.94)
      ..translate(-s * 0.515, -s * 0.553);

    final body = Path()
      ..moveTo(s * 0.330, s * 0.560)
      ..lineTo(s * 0.362, s * 0.560)
      ..quadraticBezierTo(s * 0.379, s * 0.470, s * 0.432, s * 0.458)
      ..lineTo(s * 0.556, s * 0.458)
      ..quadraticBezierTo(s * 0.615, s * 0.468, s * 0.646, s * 0.529)
      ..lineTo(s * 0.678, s * 0.545)
      ..quadraticBezierTo(s * 0.702, s * 0.555, s * 0.700, s * 0.581)
      ..lineTo(s * 0.698, s * 0.598)
      ..lineTo(s * 0.330, s * 0.598)
      ..quadraticBezierTo(s * 0.313, s * 0.581, s * 0.330, s * 0.560)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cyanBright, cyan, electricBlue],
          stops: [0, 0.52, 1],
        ).createShader(
          Rect.fromLTWH(s * 0.31, s * 0.45, s * 0.40, s * 0.16),
        ),
    );

    final glass = Path()
      ..moveTo(s * 0.404, s * 0.548)
      ..quadraticBezierTo(s * 0.418, s * 0.489, s * 0.452, s * 0.480)
      ..lineTo(s * 0.545, s * 0.480)
      ..quadraticBezierTo(s * 0.589, s * 0.489, s * 0.616, s * 0.535)
      ..lineTo(s * 0.616, s * 0.548)
      ..close();

    canvas.drawPath(
      glass,
      Paint()..color = charcoalDeep.withValues(alpha: 0.82),
    );

    for (final cx in [s * 0.400, s * 0.628]) {
      final centre = Offset(cx, s * 0.598);
      canvas.drawCircle(centre, s * 0.050, Paint()..color = charcoalDeep);
      canvas.drawCircle(
        centre,
        s * 0.050,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.014
          ..color = steel,
      );
      canvas.drawCircle(centre, s * 0.019, Paint()..color = cyan);
    }

    canvas.restore();
  }

  static Offset _polar(double angle, double radius) =>
      Offset(math.cos(angle) * radius, math.sin(angle) * radius);

  @override
  bool shouldRepaint(VehicleCareLogoPainter oldDelegate) =>
      oldDelegate.showBackground != showBackground;
}
