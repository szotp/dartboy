import 'package:flutter/material.dart';

// ignore: avoid_classes_with_only_static_members
/// Util to convert between flutter colors and RGB colors.
class ColorConverter {
  static int toRGB(Color color) {
    return color.toARGB32() & 0x00FFFFFF;
  }

  static Color toColor(int rgb) {
    return Color(0xFF000000 | rgb);
  }
}
