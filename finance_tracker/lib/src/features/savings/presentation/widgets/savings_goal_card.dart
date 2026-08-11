import "package:flutter/material.dart";

import "../../../../core/utils/currency_formatter.dart";
import "../../domain/savings_goal.dart";

class SavingsGoalCard extends StatelessWidget {
  const SavingsGoalCard({
    super.key,
    required this.goal,
    this.onTap,
    this.onDelete,
  });

  final SavingsGoal goal;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isComplete = goal.progressPercent >= 1.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12)),
    );
  }
}
