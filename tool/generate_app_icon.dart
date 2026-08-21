import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_care/core/widgets/vehicle_care_logo.dart';

const double _canvas = 1024;
const double _foregroundScale = 0.72;

Future<void> _write(String path, ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
  stdout.writeln('wrote $path (${image.width}x${image.height})');
}

Future<ui.Image> _render(void Function(Canvas canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, _canvas, _canvas),
  );
  draw(canvas);
  return recorder.endRecording().toImage(_canvas.toInt(), _canvas.toInt());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate app icons', () async {
    const size = Size(_canvas, _canvas);

    final full = await _render(
      (canvas) =>
          const VehicleCareLogoPainter().paint(canvas, size),
    );
    await _write('assets/icon/vehicle_care_icon.png', full);

    final foreground = await _render((canvas) {
      const inset = _canvas * (1 - _foregroundScale) / 2;
      canvas
        ..translate(inset, inset)
        ..scale(_foregroundScale);
      const VehicleCareLogoPainter(showBackground: false).paint(canvas, size);
    });
    await _write('assets/icon/vehicle_care_icon_foreground.png', foreground);
  });
}
