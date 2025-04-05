import 'dart:typed_data' show Float32List;
import 'dart:ui';

import 'package:dartboy/emulator/emulator.dart';
import 'package:flutter/material.dart';

import '../emulator/graphics/ppu.dart';
import '../utils/color_converter.dart';

class LCDWidget extends StatefulWidget {
  final Emulator emulator;
  const LCDWidget({super.key, required this.emulator});

  @override
  State<LCDWidget> createState() {
    return LCDState();
  }
}

class LCDState extends State<LCDWidget> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final ppu = widget.emulator.cpu?.ppu;

    if (ppu == null) {
      return SizedBox(child: Placeholder());
    }

    return CustomPaint(isComplex: true, willChange: true, painter: LCDPainter(ppu));
  }
}

/// LCD painter is used to copy the LCD data from the gameboy PPU to the screen.
class LCDPainter extends CustomPainter {
  final PPU ppu;

  /// Indicates if the LCD is drawing new content
  bool drawing = false;

  LCDPainter(this.ppu) : super(repaint: ppu);

  @override
  void paint(Canvas canvas, Size size) {
    drawing = true;

    int scale = 1;
    int width = PPU.LCD_WIDTH * scale;
    int height = PPU.LCD_HEIGHT * scale;

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        Paint color = Paint();
        color.style = PaintingStyle.stroke;
        color.strokeWidth = 1.0;

        color.color = ColorConverter.toColor(ppu.current[(x ~/ scale) + (y ~/ scale) * PPU.LCD_WIDTH]);

        List<double> points = List<double>.empty(growable: true);
        points.add(x.toDouble() - width / 2.0);
        points.add(y.toDouble() + 10);

        canvas.drawRawPoints(PointMode.points, Float32List.fromList(points), color);
      }
    }

    drawing = false;
  }

  @override
  bool shouldRepaint(LCDPainter oldDelegate) {
    return !drawing;
  }
}
