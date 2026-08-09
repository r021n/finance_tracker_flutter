import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/database/turso_client_provider.dart";
import "../data/budget_repository.dart";
import "../domain/budget.dart";

part "budget_providers.g.dart";

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(tursoClientProvider));
});

final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, String>(
  SelectedMonthNotifier.new,
);

class SelectedMonthNotifier extends Notifier<String> {
  @override
  String build() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  void setMonth(String monthYear) {
    state = monthYear;
  }
}

@Riverpod(keepAlive: true)
class BudgetListNotifier extends _$BudgetListNotifier {
  @override
  Future<List<BudgetWithProgress>> build() async {
    final monthYear = ref.watch(selectedMonthProvider);
    return ref
        .watch(budgetRepositoryProvider)
        .getBudgetsWithProgress(monthYear);
  }

  Future<void> setBudget({
    required String categoryId,
    required double amountLimit,
  }) async {
    final monthYear = ref.read(selectedMonthProvider);
    await ref
        .read(budgetRepositoryProvider)
        .setBudget(
          categoryId: categoryId,
          amountLimit: amountLimit,
          monthYear: monthYear,
        );
    ref.invalidateSelf();
  }

  Future<void> removeBudget(String id) async {
    await ref.read(budgetRepositoryProvider).deleteBudget(id);
    ref.invalidateSelf();
  }
}

@Riverpod(keepAlive: true)
class BudgetSummaryNotifier extends _$BudgetSummaryNotifier {
  @override
  Future<({double totalSpent, double totalLimit})> build() async {
    final monthYear = ref.watch(selectedMonthProvider);
    final repo = ref.watch(budgetRepositoryProvider);
    final totalSpent = await repo.getTotalSpent(monthYear);
    final totalLimit = await repo.getTotalBudgetLimit(monthYear);
    return (totalSpent: totalSpent, totalLimit: totalLimit);
  }
}
