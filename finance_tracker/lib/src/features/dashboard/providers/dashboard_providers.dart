import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/turso_client_provider.dart';
import '../../wallets/providers/wallet_providers.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

part 'dashboard_providers.g.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(tursoClientProvider));
});

@Riverpod(keepAlive: true)
class DashboardSummaryNotifier extends _$DashboardSummaryNotifier {
  @override
  Future<DashboardSummary> build() async {
    await ref.read(walletRepositoryProvider).reconcileBalances();
    final now = DateTime.now();
    final monthYear = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return ref.read(dashboardRepositoryProvider).getDashboardSummary(monthYear);
  }
}

@Riverpod(keepAlive: true)
class DailyCashFlowNotifier extends _$DailyCashFlowNotifier {
  @override
  Future<List<DailyCashFlow>> build() async {
    final now = DateTime.now();
    final monthYear = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return ref.read(dashboardRepositoryProvider).getDailyCashFlow(monthYear);
  }
}

@Riverpod(keepAlive: true)
class CategoryExpenseNotifier extends _$CategoryExpenseNotifier {
  @override
  Future<List<CategoryExpenseSummary>> build() async {
    final now = DateTime.now();
    final monthYear = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return ref.read(dashboardRepositoryProvider).getCategoryExpenses(monthYear);
  }
}
