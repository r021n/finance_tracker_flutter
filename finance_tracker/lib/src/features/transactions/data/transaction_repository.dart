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
  }
}
