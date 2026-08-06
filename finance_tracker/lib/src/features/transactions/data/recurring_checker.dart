import 'package:uuid/uuid.dart';

import '../../../core/database/turso_client.dart';
import '../domain/recurring_rule.dart';
import '../domain/transaction.dart';

const _uuid = Uuid();

class RecurringChecker {
  RecurringChecker(this._client);

  final TursoClient _client;

  Future<void> checkAndRunDueTransactions() async {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final rules = await _client.query(
      "SELECT * FROM recurring_rules WHERE next_run_date <= ?",
      args: [todayStr],
    );

    for (final ruleRow in rules) {
      final rule = RecurringRule.fromJson(ruleRow);

      final transactionId = _uuid.v4();
      final createdAt = now.toIso8601String();

      await _client.execute(
        '''
        INSERT INTO transactions (id, wallet_id, category_id, amount, type, transaction_date, note, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        args: [
          transactionId,
          rule.walletId,
          rule.categoryId,
          rule.amount,
          rule.type.name,
          todayStr,
          rule.note,
          createdAt,
        ],
      );

      final balanceChange = rule.type == TransactionType.income
          ? rule.amount
          : -rule.amount;
      await _client.execute(
        'UPDATE wallets SET balance = balance + ? WHERE id = ?',
        args: [balanceChange, rule.walletId],
      );

      final nextRun = _calculateNextRunDate(rule.frequency, now);
      await _client.execute(
        'UPDATE recurring_rules SET next_run_date = ? WHERE id = ?',
        args: [nextRun, rule.id],
      );
    }
  }

  String _calculateNextRunDate(RecurringFrequency frequency, DateTime from) {
    DateTime next;
    switch (frequency) {
      case RecurringFrequency.daily:
        next = from.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        next = from.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        next = DateTime(from.year, from.month + 1, from.day);
    }
    return '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
  }
}
