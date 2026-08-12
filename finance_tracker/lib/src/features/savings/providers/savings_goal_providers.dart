import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/database/turso_client_provider.dart";
import "../data/savings_goal_repository.dart";
import "../domain/savings_goal.dart";

part "savings_goal_providers.g.dart";

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  return SavingsGoalRepository(ref.watch(tursoClientProvider));
});

@Riverpod(keepAlive: true)
class SavingsGoalListNotifier extends _$SavingsGoalListNotifier {
  @override
  Future<List<SavingsGoal>> build() async {
    return ref.watch(savingsGoalRepositoryProvider).getSavingsGoals();
  }

  Future<void> addSavingsGoal({
    required String title,
    required double targetAmount,
    String? targetDate,
  }) async {
    final goal = await ref
        .read(savingsGoalRepositoryProvider)
        .createSavingsGoal(
          title: title,
          targetAmount: targetAmount,
          targetDate: targetDate,
        );
    final current = await future;
    state = AsyncData([...current, goal]);
  }

  Future<void> editSavingsGoal(SavingsGoal goal) async {
    await ref.read(savingsGoalRepositoryProvider).updateSavingsGoal(goal);
    final current = await future;
    state = AsyncData([for (final g in current) g.id == goal.id ? goal : g]);
  }

  Future<void> removeSavingsGoal(String id) async {
    await ref.read(savingsGoalRepositoryProvider).deleteSavingsGoal(id);
    final current = await future;
    state = AsyncData([
      for (final g in current)
        if (g.id != id) g,
    ]);
  }

  Future<void> deposit({
    required String goalId,
    required String walletId,
    required double amount,
  }) async {
    await ref
        .read(savingsGoalRepositoryProvider)
        .deposit(goalId: goalId, walletId: walletId, amount: amount);
    ref.invalidateSelf();
  }

  Future<void> withdraw({
    required String goalId,
    required String walletId,
    required double amount,
  }) async {
    await ref
        .read(savingsGoalRepositoryProvider)
        .withdraw(goalId: goalId, walletId: walletId, amount: amount);
    ref.invalidateSelf();
  }
}
