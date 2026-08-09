import "package:flutter/material.dart";

class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    super.key,
    required this.progress,
    this.height = 8.0,
    this.color,
  });

  final double progress;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? _getColor(progress);
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: []);
  }
}
