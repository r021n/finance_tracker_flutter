String formatCurrency(num amount) {
  final parts = amount.toStringAsFixed(2).split(".");
  final buffer = StringBuffer();
  for (var i = 0; i < parts[0].length; i++) {
    if (i > 0 && (parts[0].length - i) % 3 == 0) buffer.write(".");
    buffer.write(parts[0][i]);
  }
  return "Rp ${buffer.toString()},${parts[1]}";
}
