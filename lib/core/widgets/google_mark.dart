import 'package:flutter/material.dart';

/// Google's four-colour "G", drawn from Google's own path data.
///
/// **Not approximated with arcs.** The first attempt drew four arc segments and
/// a bar, on the theory that the mark is "a ring with a gap". It is not: the
/// red and green strokes taper, the blue arm is a different weight from the
/// ring, and the crossbar meets the arm at an angle. Anything built from
/// circular arcs reads as a knock-off, which is worse than no logo at all on a
/// button whose whole job is to be instantly recognised.
///
/// **Not `flutter_svg` either.** Adding an SVG renderer and its dependency tree
/// for one static mark is not a trade worth making. [_MiniPath] parses just the
/// handful of commands these four paths use, which is around sixty lines and
/// gives the real outline at any size with nothing added to the bundle.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _GoogleMarkPainter());
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  /// Google's published mark, on its 48×48 grid.
  static const _viewBox = 48.0;

  static const _paths = <(String, Color)>[
    (
      'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 '
          '14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z',
      Color(0xFFEA4335),
    ),
    (
      'M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 '
          '5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z',
      Color(0xFF4285F4),
    ),
    (
      'M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 '
          '16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z',
      Color(0xFFFBBC05),
    ),
    (
      'M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 '
          '2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z',
      Color(0xFF34A853),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewBox, size.height / _viewBox);

    final paint = Paint()..isAntiAlias = true;
    for (final (data, color) in _paths) {
      canvas.drawPath(_MiniPath.parse(data), paint..color = color);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;
}

/// An SVG path parser covering exactly the commands the mark above uses.
///
/// M/m, L/l, H/h, V/v, C/c, S/s and Z/z — no arcs, no quadratics. Deliberately
/// narrow: a general parser is a package, and this only ever has to read four
/// strings that are compiled into the binary.
class _MiniPath {
  const _MiniPath._();

  static final _token = RegExp(r'[MmLlHhVvCcSsZz]|-?\d*\.?\d+(?:e[-+]?\d+)?');

  static Path parse(String data) {
    final path = Path();
    final tokens = _token.allMatches(data).map((m) => m[0]!).toList();

    var i = 0;
    var x = 0.0;
    var y = 0.0;

    // The reflection point for a smooth curve, and the command that produced
    // it. `S` mirrors the previous control point only when the previous
    // command was itself a curve.
    var lastControlX = 0.0;
    var lastControlY = 0.0;
    var lastWasCurve = false;

    var command = '';
    double next() => double.parse(tokens[i++]);

    while (i < tokens.length) {
      final token = tokens[i];
      if (RegExp(r'[A-Za-z]').hasMatch(token)) {
        command = token;
        i++;
      }
      // No letter means the previous command repeats with fresh operands,
      // which is how these paths chain their curves.

      final relative = command == command.toLowerCase();
      final originX = relative ? x : 0.0;
      final originY = relative ? y : 0.0;

      switch (command.toUpperCase()) {
        case 'M':
          x = originX + next();
          y = originY + next();
          path.moveTo(x, y);
          // A second coordinate pair after M is an implicit lineto.
          command = relative ? 'l' : 'L';
          lastWasCurve = false;
        case 'L':
          x = originX + next();
          y = originY + next();
          path.lineTo(x, y);
          lastWasCurve = false;
        case 'H':
          x = originX + next();
          path.lineTo(x, y);
          lastWasCurve = false;
        case 'V':
          y = originY + next();
          path.lineTo(x, y);
          lastWasCurve = false;
        case 'C':
          final c1x = originX + next();
          final c1y = originY + next();
          final c2x = originX + next();
          final c2y = originY + next();
          x = originX + next();
          y = originY + next();
          path.cubicTo(c1x, c1y, c2x, c2y, x, y);
          lastControlX = c2x;
          lastControlY = c2y;
          lastWasCurve = true;
        case 'S':
          final c1x = lastWasCurve ? 2 * x - lastControlX : x;
          final c1y = lastWasCurve ? 2 * y - lastControlY : y;
          final c2x = originX + next();
          final c2y = originY + next();
          x = originX + next();
          y = originY + next();
          path.cubicTo(c1x, c1y, c2x, c2y, x, y);
          lastControlX = c2x;
          lastControlY = c2y;
          lastWasCurve = true;
        case 'Z':
          path.close();
          lastWasCurve = false;
      }
    }

    return path;
  }
}
