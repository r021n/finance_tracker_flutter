import 'package:uuid/uuid.dart';

import '../../../core/database/turso_client.dart';
import '../domain/recurring_rule.dart';
import '../domain/transaction.dart';

const _uuid = Uuid();

class RecurringRepository {
  RecurringRepository(this._client);

  final TursoClient _client;

  Future<List<RecurringRule>> getRecurringRules() async {
    final rows = await _client.query(
      'SELECT * FROM recurring_rules ORDER BY next_run_date ASC',
    );
    return rows.map(RecurringRule.fromJson).toList();
  }

  Future<RecurringRule> createRecurringRule({
    required String walletId,
    String? categoryId,
    required double amount,
    required TransactionType type,
    required RecurringFrequency frequency,
    required String nextRunDate,
    String? note,
  }) async {
    final id = _uuid.v4();

    await _client.execute(
      '''
      INSERT INTO recurring_rules (id, wallet_id, category_id, amount, type, frequency, next_run_date, note)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      args: [
        id,
        walletId,
        categoryId,
        amount,
        type.name,
        frequency.name,
        nextRunDate,
        note,
      ],
    );

    return RecurringRule(
      id: id,
      walletId: walletId,
      categoryId: categoryId,
      amount: amount,
      type: type,
      frequency: frequency,
      nextRunDate: nextRunDate,
      note: note,
    );
  }

  Future<void> updateNextRunDate(String id, String nextRunDate) async {
    await _client.execute(
      'UPDATE recurring_rules SET next_run_date = ? WHERE id = ?',
      args: [nextRunDate, id],
    );
  }

  Future<void> deleteRecurringRule(String id) async {
    await _client.execute(
      'DELETE FROM recurring_rules WHERE id = ?',
      args: [id],
    );
  }
}
