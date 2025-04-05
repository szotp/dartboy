import 'dart:io';

import 'package:emulator/emulator.dart';
import 'package:emulator/graphics/ppu.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    final rom = File("/Users/pawelszot/Development/dartboy/assets/pokemon.gb").readAsBytesSync();

    test('First Test', () {
      final emulator = Emulator();
      emulator.loadROM(rom);

      for (int i = 0; i < 200; i++) {
        emulator.stepFrame();
      }

      img.encodePngFile("output.png", emulator.cpu!.ppu.makeSnapshot());
    });
  });
}

extension on PPU {
  img.Image makeSnapshot() {
    final image = img.Image(width: PPU.LCD_WIDTH, height: PPU.LCD_HEIGHT);

    const int width = PPU.LCD_WIDTH;
    const int height = PPU.LCD_HEIGHT;

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final pixel = current[x + y * PPU.LCD_WIDTH];
        final r = (pixel >> 16) & 0xFF;
        final g = (pixel >> 8) & 0xFF;
        final b = pixel & 0xFF;
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }
}
