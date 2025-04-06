import 'dart:io';

import 'package:emulator/configuration.dart';
import 'package:emulator/emulator.dart';
import 'package:emulator/graphics/ppu.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

const repo = '/Users/pawelszot/Downloads/gb-test-roms-master';

void main() {
  group('cpu_instrs', () {
    test('01-special.gb', () {
      final rom = File('$repo/cpu_instrs/individual/01-special.gb').readAsBytesSync();
      final emulator = Emulator(Configuration());

      emulator.configuration.setSerialPortHandler((x) {
        if (x.startsWith("Failed")) {
          print(x);
          emulator.pause();
        }
      });
      emulator.loadROM(rom);

      for (int i = 0; i < 200; i++) {
        emulator.stepFrame();
      }

      img.encodePngFile("output.png", emulator.cpu!.ppu.makeSnapshot());
    });
  });
}

extension on Configuration {
  void setSerialPortHandler(void Function(String) callback) {
    final buffer = StringBuffer();

    onCharacter = (x) {
      if (x == '\n') {
        final line = "$buffer";
        buffer.clear();

        callback(line);
      } else {
        buffer.write(x);
      }
    };
  }
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
