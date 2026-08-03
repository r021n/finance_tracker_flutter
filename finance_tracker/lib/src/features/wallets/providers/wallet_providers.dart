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

  // next progress (03 agustus 2026, 14:28)
}
