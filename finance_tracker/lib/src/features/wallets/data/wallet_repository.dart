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
}
