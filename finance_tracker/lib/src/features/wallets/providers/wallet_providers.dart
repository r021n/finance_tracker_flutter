import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/database/turso_client_provider.dart";
import "../data/wallet_repository.dart";
import "../domain/wallet.dart";

part "wallet_providers.g.dart";

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(tursoClientProvider));
});

@Riverpod(keepAlive: true)
class WalletListNotifier extends _$WalletListNotifier {
  @override
  Future<List<Wallet>> build() async {
    return ref.watch(walletRepositoryProvider).getWallets();
  }

  Future<void> addWallet({
    required String name,
    required WalletType type,
    required double initialBalance,
    String? icon,
    String? color,
  }) async {
    final wallet = await ref
        .read(walletRepositoryProvider)
        .createWallet(
          name: name,
          type: type,
          initialBalance: initialBalance,
          icon: icon,
          color: color,
        );
    final current = await future;
    state = AsyncData([...current, wallet]);
  }

  Future<void> editWallet(Wallet wallet) async {
    await ref.read(walletRepositoryProvider).updateWallet(wallet);
    final current = await future;
    state = AsyncData([
      for (final w in current) w.id == wallet.id ? wallet : w,
    ]);
  }

  Future<void> removeWallet(String id) async {
    await ref.read(walletRepositoryProvider).deleteWallet(id);
    final current = await future;
    state = AsyncData([
      for (final w in current)
        if (w.id != id) w,
    ]);
  }
}
