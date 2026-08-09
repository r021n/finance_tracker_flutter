import "package:uuid/uuid.dart";

import "../../../core/database/turso_client.dart";
import "../domain/budget.dart";

const _uuid = Uuid();

class BudgetRepository {
  BudgetRepository(this._client);

  final TursoClient _client;

  Future<List<BudgetWithProgress>> getBudgetsWithProgress(
    String monthYear,
  ) async {
    final rows = await _client.query(
      '''
      SELECT
        b.id            AS budget_id,
        b.category_id,
        b.amount_limit,
        b.month_year,
        b.created_at    AS budget_created_at,
        c.name          AS category_name,
        c.icon          AS category_icon,
        c.color         AS category_color,
        COALESCE(SUM(t.amount), 0) AS spent
      FROM budgets b
      JOIN categories c ON c.id = b.category_id
      LEFT JOIN transactions t
        ON t.category_id = b.category_id
        AND t.type = 'expense'
        AND strftime('%Y-%m', t.transaction_date) = b.month_year
      WHERE b.month_year = ?
      GROUP BY b.id
      ORDER BY c.name ASC
      ''',
      args: [monthYear],
    );

    return rows.map((row) {
      final budget = Budget(
        id: row['budget_id'] as String,
        categoryId: row['category_id'] as String,
        amountLimit: (row['amount_limit'] as num).toDouble(),
        monthYear: row['month_year'] as String,
        createdAt: row['budget_created_at'] as String?,
      );

      return BudgetWithProgress(
        budget: budget,
        categoryName: row['category_name'] as String,
        categoryIcon: row['category_icon'] as String?,
        categoryColor: row['category_color'] as String?,
        spent: (row['spent'] as num).toDouble(),
      );
    }).toList();
  }

  Future<Budget> setBudget({
    required String categoryId,
    required double amountLimit,
    required String monthYear,
  }) async {
    final existing = await _client.query(
      'SELECT id FROM budgets WHERE category_id = ? AND month_year = ?',
      args: [categoryId, monthYear],
    );

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as String;
      await _client.execute(
        'UPDATE budgets SET amount_limit = ? WHERE id = ?',
        args: [amountLimit, id],
      );
      return Budget(
        id: id,
        categoryId: categoryId,
        amountLimit: amountLimit,
        monthYear: monthYear,
      );
    }

    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();
    await _client.execute(
      '''
      INSERT INTO budgets (id, category_id, amount_limit, month_year, created_at)
      VALUES (?, ?, ?, ?, ?)
      ''',
      args: [id, categoryId, amountLimit, monthYear, now],
    );

    return Budget(
      id: id,
      categoryId: categoryId,
      amountLimit: amountLimit,
      monthYear: monthYear,
      createdAt: now,
    );
  }

  Future<void> deleteBudget(String id) async {
    await _client.execute('DELETE FROM budgets WHERE id = ?', args: [id]);
  }

  Future<double> getTotalSpent(String monthYear) async {
    final rows = await _client.query(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE type = 'expense'
        AND strftime('%Y-%m', transaction_date) = ?
      ''',
      args: [monthYear],
    );
    return (rows.first['total'] as num).toDouble();
  }

  Future<double> getTotalBudgetLimit(String monthYear) async {
    final rows = await _client.query(
      'SELECT COALESCE(SUM(amount_limit), 0) AS total FROM budgets WHERE month_year = ?',
      args: [monthYear],
    );
    return (rows.first['total'] as num).toDouble();
  }
}
