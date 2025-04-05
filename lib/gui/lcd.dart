import 'dart:typed_data' show Float32List;
import 'dart:ui';

import 'package:dartboy/utils/color_converter.dart';
import 'package:emulator/emulator.dart';
import 'package:emulator/graphics/ppu.dart';
import 'package:flutter/material.dart';

class EmulatorScreenWidget extends StatelessWidget {
  final Emulator emulator;
  const EmulatorScreenWidget({super.key, required this.emulator});

  @override
  Widget build(BuildContext context) {
    final ppu = emulator.cpu?.ppu;

    if (ppu == null) {
      return const SizedBox(child: Placeholder());
    }

    return Container(
      color: Colors.grey[800],
      child: FittedBox(
        child: CustomPaint(isComplex: true, willChange: true, painter: _LCDPainter(ppu), size: Size(PPU.LCD_WIDTH.toDouble(), PPU.LCD_HEIGHT.toDouble())),
      ),
    );
  }
}

class _PPUListenable extends ChangeNotifier {
  final PPU ppu;

  _PPUListenable(this.ppu) {
    ppu.notifyListeners = notifyListeners;
  }
}

/// LCD painter is used to copy the LCD data from the gameboy PPU to the screen.
class _LCDPainter extends CustomPainter {
  final PPU ppu;

  _LCDPainter(this.ppu) : super(repaint: _PPUListenable(ppu));

  @override
  void paint(Canvas canvas, Size size) {
    const int width = PPU.LCD_WIDTH;
    const int height = PPU.LCD_HEIGHT;

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final Paint color = Paint();
        color.style = PaintingStyle.stroke;
        color.strokeWidth = 1.0;

        color.color = ColorConverter.toColor(ppu.current[x + y * PPU.LCD_WIDTH]);

        final List<double> points = List<double>.empty(growable: true);
        points.add(x.toDouble());
        points.add(y.toDouble());

        canvas.drawRawPoints(PointMode.points, Float32List.fromList(points), color);
      }
    }
  }

  @override
  bool shouldRepaint(_LCDPainter oldDelegate) {
    return true;
  }
}
