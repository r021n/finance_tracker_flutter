import "package:flutter/material.dart";

Color colorFromHex(String? hex, {Color fallback = Colors.green}) {
  if (hex == null || hex.isEmpty) return fallback;
  var value = hex.replaceFirst("#", "");
  if (value.length == 6) value = "FF$value";
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

String colorToHex(Color color) {
  final rgb = (color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, "0");
  return "#${rgb.toUpperCase()}";
}
