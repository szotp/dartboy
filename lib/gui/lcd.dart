import 'dart:typed_data' show Float32List;
import 'dart:ui';

import 'package:emulator/emulator.dart';
import 'package:emulator/graphics/ppu.dart';
import 'package:flutter/material.dart';

import '../utils/color_converter.dart';

class LCDWidget extends StatefulWidget {
  final Emulator emulator;
  const LCDWidget({super.key, required this.emulator});

  @override
  State<LCDWidget> createState() {
    return _LCDState();
  }
}

class _LCDState extends State<LCDWidget> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final ppu = widget.emulator.cpu?.ppu;

    if (ppu == null) {
      return SizedBox(child: Placeholder());
    }

    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Transform.scale(
          scale: 3,
          child: CustomPaint(isComplex: true, willChange: true, painter: LCDPainter(ppu), size: Size(PPU.LCD_WIDTH.toDouble(), PPU.LCD_HEIGHT.toDouble())),
        ),
      ),
    );
  }
}

class PPUListenable extends ChangeNotifier {
  final PPU ppu;

  PPUListenable(this.ppu) {
    ppu.notifyListeners = notifyListeners;
  }
}

/// LCD painter is used to copy the LCD data from the gameboy PPU to the screen.
class LCDPainter extends CustomPainter {
  final PPU ppu;

  LCDPainter(this.ppu) : super(repaint: PPUListenable(ppu));

  @override
  void paint(Canvas canvas, Size size) {
    int width = PPU.LCD_WIDTH;
    int height = PPU.LCD_HEIGHT;

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        Paint color = Paint();
        color.style = PaintingStyle.stroke;
        color.strokeWidth = 1.0;

        color.color = ColorConverter.toColor(ppu.current[x + y * PPU.LCD_WIDTH]);

        List<double> points = List<double>.empty(growable: true);
        points.add(x.toDouble());
        points.add(y.toDouble());

        canvas.drawRawPoints(PointMode.points, Float32List.fromList(points), color);
      }
    }
  }

  @override
  bool shouldRepaint(LCDPainter oldDelegate) {
    return true;
  }
}
