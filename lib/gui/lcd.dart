import 'dart:ui';

import 'package:emulator/emulator.dart';
import 'package:emulator/graphics/ppu.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart' hide Image;

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
        child: CustomPaint(
          isComplex: true,
          willChange: true,
          painter: _LCDPainter(_PPUListenable(ppu)),
          size: Size(PPU.LCD_WIDTH.toDouble(), PPU.LCD_HEIGHT.toDouble()),
        ),
      ),
    );
  }
}

class _PPUListenable extends ChangeNotifier {
  final PPU ppu;

  Image? image;

  _PPUListenable(this.ppu) {
    ppu.notifyListeners = (buffer) {
      decodeImageFromPixels(buffer.buffer.asUint8List(), PPU.LCD_WIDTH, PPU.LCD_HEIGHT, PixelFormat.rgba8888, (image) {
        this.image = image;
        notifyListeners();
      });
    };
  }
}

/// LCD painter is used to copy the LCD data from the gameboy PPU to the screen.
class _LCDPainter extends CustomPainter {
  final _PPUListenable listenable;

  _LCDPainter(this.listenable) : super(repaint: listenable);

  @override
  void paint(Canvas canvas, Size size) {
    final image = listenable.image;

    if (image == null) {
      return;
    }

    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(_LCDPainter oldDelegate) {
    return true;
  }
}
