import '../../../core/database/turso_client.dart';
import '../domain/dashboard_summary.dart';

class DashboardRepository {
  DashboardRepository(this._client);

  final TursoClient _client;

  Future<double> getTotalBalance() async {
    final rows = await _client.query(
      'SELECT COALESCE(SUM(balance), 0) AS total FROM wallets',
    );
    return (rows.first['total'] as num).toDouble();
  }

  Future<double> getMonthlyIncome(String monthYear) async {
    final rows = await _client.query(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE type = 'income'
        AND strftime('%Y-%m', transaction_date) = ?
      ''',
      args: [monthYear],
    );
    return (rows.first['total'] as num).toDouble();
  }

  Future<double> getMonthlyExpense(String monthYear) async {
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

  Future<List<DailyCashFlow>> getDailyCashFlow(String monthYear) async {
    final rows = await _client.query(
      '''
      SELECT
        transaction_date AS date,
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) AS income,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) AS expense
      FROM transactions
      WHERE strftime('%Y-%m', transaction_date) = ?
      GROUP BY transaction_date
      ORDER BY transaction_date ASC
      ''',
      args: [monthYear],
    );

    return rows
        .map(
          (row) => DailyCashFlow(
            date: row['date'] as String,
            income: (row['income'] as num).toDouble(),
            expense: (row['expense'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<List<CategoryExpenseSummary>> getCategoryExpenses(
    String monthYear,
  ) async {
    final rows = await _client.query(
      '''
      SELECT
        c.name AS category_name,
        c.color AS category_color,
        SUM(t.amount) AS total
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.type = 'expense'
        AND strftime('%Y-%m', t.transaction_date) = ?
      GROUP BY t.category_id
      ORDER BY total DESC
      ''',
      args: [monthYear],
    );

    return rows
        .map(
          (row) => CategoryExpenseSummary(
            categoryName: row['category_name'] as String? ?? 'Tanpa Kategori',
            categoryColor: row['category_color'] as String?,
            total: (row['total'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<DashboardSummary> getDashboardSummary(String monthYear) async {
    final totalBalance = await getTotalBalance();
    final monthlyIncome = await getMonthlyIncome(monthYear);
    final monthlyExpense = await getMonthlyExpense(monthYear);

    return DashboardSummary(
      totalBalance: totalBalance,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
    );
  }
}
