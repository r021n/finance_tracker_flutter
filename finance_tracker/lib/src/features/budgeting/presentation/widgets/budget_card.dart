import "package:flutter/material.dart";

import "../../../../core/utils/color_utils.dart";
import "../../../../core/utils/currency_formatter.dart";
import "../../../../shared/constants/app_icons.dart";
import "../../domain/budget.dart";
import "budget_progress_bar.dart";

class BudgetCard extends StatelessWidget {
  const BudgetCard({super.key, required this.item, this.onDelete});

  final BudgetWithProgress item;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(item.categoryColor);
    final isOverbudget = item.usagePercent > 1.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(iconFromName(item.categoryIcon), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.categoryName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Batas: ${formatCurrency(item.budget.amountLimit)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Hapus anggaran',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            BudgetProgressBar(progress: item.usagePercent),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Terpakai: ${formatCurrency(item.spent)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isOverbudget ? Colors.red : Colors.grey.shade700,
                    fontWeight: isOverbudget
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                Text(
                  isOverbudget
                      ? 'Over ${formatCurrency(item.spent - item.budget.amountLimit)}'
                      : 'Sisa: ${formatCurrency(item.remaining)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isOverbudget ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
