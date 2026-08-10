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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Container(width: double.infinity, color: Colors.grey.shade200),
                FractionallySizedBox(
                  widthFactor: clampedProgress,
                  child: Container(color: barColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: barColor,
          ),
        ),
      ],
    );
  }

  Color _getColor(double percent) {
    if (percent > 0.9) return Colors.red;
    if (percent > 0.7) return Colors.orange;
    return Colors.green;
  }
}
