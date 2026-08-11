import "package:uuid/uuid.dart";

import "../../../core/database/turso_client.dart";
import "../domain/savings_goal.dart";

const _uuid = Uuid();

class SavingsGoalRepository {
  SavingsGoalRepository(this._client);

  final TursoClient _client;

  Future<List<SavingsGoal>> getSavingsGoals() async {
    final rows = await _client.query(
      "SELECT * FROM savings_goals ORDER BY created_at ASC",
    );
    return rows.map(SavingsGoal.fromJson).toList();
  }

  Future<SavingsGoal> createSavingsGoal({
    required String title,
    required double targetAmount,
    String? targetDate,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();

    await _client.execute(
      '''
      INSERT INTO savings_goals (id, title, target_amount, current_amount, target_date, created_at)
      VALUES (?, ?, ?, 0, ?, ?)
      ''',
      args: [id, title, targetAmount, targetDate, now],
    );

    return SavingsGoal(
      id: id,
      title: title,
      targetAmount: targetAmount,
      targetDate: targetDate,
      createdAt: now,
    );
  }

  Future<void> updateSavingsGoal(SavingsGoal goal) async {
    await _client.execute(
      '''
      UPDATE savings_goals
      SET title = ?, target_amount = ?, target_date = ?
      WHERE id = ?
      ''',
      args: [goal.title, goal.targetAmount, goal.targetDate, goal.id],
    );
  }

  Future<void> deleteSavingsGoal(String id) async {
    await _client.execute("DELETE FROM savings_goals WHERE id = ?", args: [id]);
  }

  Future<void> deposit({
    required String goalId,
    required String walletId,
    required double amount,
  }) async {
    if (amount <= 0) return;

    await _client.execute(
      'UPDATE wallets SET balance = balance - ? WHERE id = ?',
      args: [amount, walletId],
    );

    await _client.execute(
      'UPDATE savings_goals SET current_amount = current_amount + ? WHERE id = ?',
      args: [amount, goalId],
    );
  }

  Future<void> withdraw({
    required String goalId,
    required String walletId,
    required double amount,
  }) async {
    if (amount <= 0) return;

    final rows = await _client.query(
      'SELECT current_amount FROM savings_goals WHERE id = ?',
      args: [goalId],
    );

    if (rows.isEmpty) return;

    final currentAmount = (rows.first['current_amount'] as num).toDouble();
    final withdrawAmount = amount > currentAmount ? currentAmount : amount;

    await _client.execute(
      'UPDATE wallets SET balance = balance + ? WHERE id = ?',
      args: [withdrawAmount, walletId],
    );

    await _client.execute(
      'UPDATE savings_goals SET current_amount = current_amount - ? WHERE id = ?',
      args: [withdrawAmount, goalId],
    );
  }
}
