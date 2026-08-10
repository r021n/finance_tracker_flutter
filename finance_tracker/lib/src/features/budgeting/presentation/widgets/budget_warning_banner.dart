import "package:flutter/material.dart";

import "../../../../core/utils/currency_formatter.dart";

class BudgetWarningBanner extends StatelessWidget {
  const BudgetWarningBanner({
    super.key,
    required this.totalSpent,
    required this.totalLimit,
  });

  final double totalSpent;
  final double totalLimit;

  @override
  Widget build(BuildContext context) {
    if (totalLimit <= 0) return const SizedBox.shrink();

    final percent = totalSpent / totalLimit;
    final isWarning = percent >= 0.7;
    final isOverbudget = percent >= 1.0;

    if (!isWarning) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverbudget ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverbudget ? Colors.red.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOverbudget ? Icons.error : Icons.warning,
            color: isOverbudget ? Colors.red : Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOverbudget
                      ? 'Anggaran Telah Terlampaui!'
                      : 'Hampir Melebihi Anggaran',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOverbudget ? Colors.red : Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOverbudget
                      ? 'Pengeluaran ${formatCurrency(totalSpent)} melebihi anggaran ${formatCurrency(totalLimit)}'
                      : 'Pengeluaran ${formatCurrency(totalSpent)} dari ${formatCurrency(totalLimit)} (${(percent * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
