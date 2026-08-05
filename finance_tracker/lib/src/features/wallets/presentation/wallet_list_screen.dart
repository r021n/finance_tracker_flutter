import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/wallet_providers.dart";
import "add_edit_wallet_bottom_sheet.dart";
import "widgets/wallet_card.dart";

class WalletListScreen extends ConsumerWidget {
  const WalletListScreen({super.key});

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddEditWalletBottomSheet(),
    );
  }

  void _openEditSheet(BuildContext context, wallet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddEditWalletBottomSheet(wallet: wallet),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Dompet")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(context),
        child: const Icon(Icons.add),
      ),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Gagal memuat dompet: $error"),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(walletListProvider),
                child: const Text("Coba Lagi"),
              ),
            ],
          ),
        ),
        data: (wallets) {
          if (wallets.isEmpty) {
            return const Center(
              child: Text("Belum ada dompet. Ketuk + untuk membuat"),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(walletListProvider.future),
            child: ListView.builder(
              itemCount: wallets.length,
              itemBuilder: (context, index) => WalletCard(
                wallet: wallets[index],
                onTap: () => _openEditSheet(context, wallets[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}
