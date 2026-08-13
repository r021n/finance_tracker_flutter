import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/savings_goal_providers.dart";
import "widgets/savings_goal_card.dart";
import "deposit_withdraw_goal_dialog.dart";
import "add_edit_savings_goal_dialog.dart";

class SavingsGoalListScreen extends ConsumerWidget {
  const SavingsGoalListScreen({super.key});

  void _openAddDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const AddEditSavingsGoalDialog(),
    );

    if (result != null) {
      await ref
          .read(savingsGoalListProvider.notifier)
          .addSavingsGoal(
            title: result['title'] as String,
            targetAmount: result['targetAmount'] as double,
            targetDate: result['targetDate'] as String?,
          );
    }
  }

  void _openDepositWithdraw(
    BuildContext context,
    WidgetRef ref, {
    required String goalId,
    required String goalTitle,
    required bool isDeposit,
    required double currentAmount,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DepositWithdrawGoalDialog(
        goalTitle: goalTitle,
        isDeposit: isDeposit,
        currentAmount: currentAmount,
      ),
    );

    if (result != null) {
      final notifier = ref.read(savingsGoalListProvider.notifier);
      if (isDeposit) {
        await notifier.deposit(
          goalId: goalId,
          walletId: result['walletId'] as String,
          amount: result['amount'] as double,
        );
      } else {
        await notifier.withdraw(
          goalId: goalId,
          walletId: result['walletId'] as String,
          amount: result['amount'] as double,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Tabungan'),
        actions: [
          IconButton(
            onPressed: () => _openAddDialog(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Target Tabungan',
          ),
        ],
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat target tabungan: $e'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(savingsGoalListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.savings_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Belum ada target tabungan'),
                  SizedBox(height: 4),
                  Text(
                    'Ketuk tombol + untuk membuat target baru',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(savingsGoalListProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                return SavingsGoalCard(
                  goal: goal,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.add_circle_outline),
                              title: const Text('Setor ke Tabungan'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _openDepositWithdraw(
                                  context,
                                  ref,
                                  goalId: goal.id,
                                  goalTitle: goal.title,
                                  isDeposit: true,
                                  currentAmount: goal.currentAmount,
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.remove_circle_outline),
                              title: const Text('Tarik dari Tabungan'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _openDepositWithdraw(
                                  context,
                                  ref,
                                  goalId: goal.id,
                                  goalTitle: goal.title,
                                  isDeposit: false,
                                  currentAmount: goal.currentAmount,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onDelete: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Hapus Target Tabungan?"),
                        content: Text('Hapus target "${goal.title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref
                          .read(savingsGoalListProvider.notifier)
                          .removeSavingsGoal(goal.id);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
