import 'package:uuid/uuid.dart';

import '../../../core/database/turso_client.dart';
import '../domain/transaction.dart';

const _uuid = Uuid();

class TransactionRepository {
  TransactionRepository(this._client);

  final TursoClient _client;

  Future<List<Transaction>> getTransactions({
    String? walletId,
    String? categoryId,
    String? startDate,
    String? endDate,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (walletId != null) {
      conditions.add('wallet_id = ?');
      args.add(walletId);
    }
    if (categoryId != null) {
      conditions.add('category_id = ?');
      args.add(categoryId);
    }
    if (startDate != null) {
      conditions.add('transaction_date >= ?');
      args.add(startDate);
    }
    if (endDate != null) {
      conditions.add('transaction_date <= ?');
      args.add(endDate);
    }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final rows = await _client.query(
      'SELECT * FROM transactions $where ORDER BY transaction_date DESC',
      args: args.isEmpty ? null : args,
    );

    return rows.map(Transaction.fromJson).toList();
  }

  Future<Transaction> addTransaction({
    required String walletId,
    String? categoryId,
    required double amount,
    required TransactionType type,
    required String transactionDate,
    String? note,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();

    await _client.execute(
      '''
      INSERT INTO transactions (id, wallet_id, category_id, amount, type, transaction_date, note, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      args: [
        id,
        walletId,
        categoryId,
        amount,
        type.name,
        transactionDate,
        note,
        now,
      ],
    );

    final balanceChange = type == TransactionType.income ? amount : -amount;
    await _client.execute(
      'UPDATE wallets SET balance = balance + ? WHERE id = ?',
      args: [balanceChange, walletId],
    );

    return Transaction(
      id: id,
      walletId: walletId,
      categoryId: categoryId,
      amount: amount,
      type: type,
      transactionDate: transactionDate,
      note: note,
      createdAt: now,
    );
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final old = await _client.query(
      'SELECT * FROM transactions WHERE id = ?',
      args: [transaction.id],
    );

    if (old.isEmpty) return;

    final oldTransaction = Transaction.fromJson(old.first);

    await _client.execute(
      '''
      UPDATE transactions
      SET wallet_id = ?, category_id = ?, amount = ?, type = ?, transaction_date = ?, note = ?
      WHERE id = ?
      ''',
      args: [
        transaction.walletId,
        transaction.categoryId,
        transaction.amount,
        transaction.type.name,
        transaction.transactionDate,
        transaction.note,
        transaction.id,
      ],
    );

    if (oldTransaction.walletId != transaction.walletId) {
      final oldChange = oldTransaction.type == TransactionType.income
          ? -oldTransaction.amount
          : oldTransaction.amount;
      await _client.execute(
        'UPDATE wallets SET balance = balance + ? WHERE id = ?',
        args: [oldChange, oldTransaction.walletId],
      );

      final newChange = transaction.type == TransactionType.income
          ? transaction.amount
          : -transaction.amount;
      await _client.execute(
        'UPDATE wallets SET balance = balance + ? WHERE id = ?',
        args: [newChange, transaction.walletId],
      );
    } else if (oldTransaction.amount != transaction.amount ||
        oldTransaction.type != transaction.type) {
      final oldChange = oldTransaction.type == TransactionType.income
          ? -oldTransaction.amount
          : oldTransaction.amount;
      final newChange = transaction.type == TransactionType.income
          ? transaction.amount
          : -transaction.amount;
      final diff = newChange - oldChange;
      await _client.execute(
        'UPDATE wallets SET balance = balance + ? WHERE id = ?',
        args: [diff, transaction.walletId],
      );
    }
  }

  Future<void> deleteTransaction(String id) async {
    final rows = await _client.query(
      'SELECT * FROM transactions WHERE id = ?',
      args: [id],
    );
    if (rows.isEmpty) return;

    final transaction = Transaction.fromJson(rows.first);

    final rollback = transaction.type == TransactionType.income
        ? -transaction.amount
        : transaction.amount;

    await _client.execute(
      'UPDATE wallets SET balance = balance + ? WHERE id = ?',
      args: [rollback, transaction.walletId],
    );

    await _client.execute('DELETE FROM transactions WHERE id = ?', args: [id]);
  }
}
