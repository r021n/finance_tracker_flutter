import "package:uuid/uuid.dart";

import "../../../core/database/turso_client.dart";
import "../domain/wallet.dart";

const _uuid = Uuid();

class WalletRepository {
  WalletRepository(this._client);

  final TursoClient _client;

  Future<List<Wallet>> getWallets() async {
    final rows = await _client.query(
      "SELECT * FROM wallets ORDER BY created_at ASC",
    );
    return rows.map(Wallet.fromJson).toList();
  }

  Future<Wallet> createWallet({
    required String name,
    required WalletType type,
    required double initialBalance,
    String? icon,
    String? color,
  }) async {
    final now = DateTime.now().toIso8601String();
    final wallet = Wallet(
      id: _uuid.v4(),
      name: name,
      type: type,
      balance: initialBalance,
      icon: icon,
      color: color,
      createdAt: now,
    );

    await _client.execute(
      '''
      INSERT INTO wallets (id, name, type, balance, icon, color, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      args: [
        wallet.id,
        wallet.name,
        wallet.type.name,
        wallet.balance,
        wallet.icon,
        wallet.color,
        wallet.createdAt,
      ],
    );
    return wallet;
  }

  Future<void> updateWallet(Wallet wallet) async {
    await _client.execute(
      '''
      UPDATE wallets
      SET name = ?, type = ?, icon = ?, color = ?
      WHERE id = ?
      ''',
      args: [
        wallet.name,
        wallet.type.name,
        wallet.icon,
        wallet.color,
        wallet.id,
      ],
    );
  }

  Future<void> deleteWallet(String id) async {
    await _client.execute("DELETE FROM wallets WHERE id = ?", args: [id]);
  }

  Future<void> reconcileBalances() async {
    final wallets = await getWallets();
    final txRows = await _client.query(
      'SELECT wallet_id, type, amount FROM transactions',
    );

    final balanceMap = <String, double>{};
    for (final w in wallets) {
      balanceMap[w.id] = 0;
    }

    for (final row in txRows) {
      final walletId = row['wallet_id'] as String;
      final type = row['type'] as String;
      final amount = (row['amount'] as num).toDouble();
      final current = balanceMap[walletId] ?? 0;
      balanceMap[walletId] = type == 'income' ? current + amount : current - amount;
    }

    for (final entry in balanceMap.entries) {
      await _client.execute(
        'UPDATE wallets SET balance = ? WHERE id = ?',
        args: [entry.value, entry.key],
      );
    }
  }
}
