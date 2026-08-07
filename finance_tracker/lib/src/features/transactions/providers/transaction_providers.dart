import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/turso_client_provider.dart';
import '../data/transaction_repository.dart';
import '../data/recurring_repository.dart';
import '../domain/transaction.dart';
import '../domain/recurring_rule.dart';

part 'transaction_providers.g.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(tursoClientProvider));
});

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(ref.watch(tursoClientProvider));
});

class TransactionFilter {
  const TransactionFilter({
    this.walletId,
    this.categoryId,
    this.startDate,
    this.endDate,
    this.searchQuery,
  });

  final String? walletId;
  final String? categoryId;
  final String? startDate;
  final String? endDate;
  final String? searchQuery;

  TransactionFilter copyWith({
    String? walletId,
    String? categoryId,
    String? startDate,
    String? endDate,
    String? searchQuery,
    bool clearWalletId = false,
    bool clearCategoryId = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearSearchQuery = false,
  }) {
    return TransactionFilter(
      walletId: clearWalletId ? null : (walletId ?? this.walletId),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
    );
  }
}

class TransactionFilterState extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => const TransactionFilter();

  void update(TransactionFilter newState) => state = newState;

  void updateWalletId(String? walletId) =>
      state = state.copyWith(walletId: walletId);

  void updateCategoryId(String? categoryId) =>
      state = state.copyWith(categoryId: categoryId);

  void updateStartDate(String? startDate) =>
      state = state.copyWith(startDate: startDate);

  void updateEndDate(String? endDate) =>
      state = state.copyWith(endDate: endDate);

  void updateSearchQuery(String? searchQuery) =>
      state = state.copyWith(searchQuery: searchQuery);

  void clearAll() => state = const TransactionFilter();
}

final transactionFilterProvider =
    NotifierProvider<TransactionFilterState, TransactionFilter>(
      TransactionFilterState.new,
    );

@Riverpod(keepAlive: true)
class TransactionListNotifier extends _$TransactionListNotifier {
  @override
  Future<List<Transaction>> build() async {
    final filter = ref.watch(transactionFilterProvider);
    return ref
        .read(transactionRepositoryProvider)
        .getTransactions(
          walletId: filter.walletId,
          categoryId: filter.categoryId,
          startDate: filter.startDate,
          endDate: filter.endDate,
        );
  }

  Future<Transaction> addTransaction({
    required String walletId,
    String? categoryId,
    required double amount,
    required TransactionType type,
    required String transactionDate,
    String? note,
  }) async {
    final transaction = await ref
        .read(transactionRepositoryProvider)
        .addTransaction(
          walletId: walletId,
          categoryId: categoryId,
          amount: amount,
          type: type,
          transactionDate: transactionDate,
          note: note,
        );
    ref.invalidateSelf();
    return transaction;
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await ref
        .read(transactionRepositoryProvider)
        .updateTransaction(transaction);
    ref.invalidateSelf();
  }

  Future<void> deleteTransaction(String id) async {
    await ref.read(transactionRepositoryProvider).deleteTransaction(id);
    ref.invalidateSelf();
  }
}

@Riverpod(keepAlive: true)
class RecurringRuleListNotifier extends _$RecurringRuleListNotifier {
  @override
  Future<List<RecurringRule>> build() async {
    return ref.read(recurringRepositoryProvider).getRecurringRules();
  }

  Future<void> addRecurringRule({
    required String walletId,
    String? categoryId,
    required double amount,
    required TransactionType type,
    required RecurringFrequency frequency,
    required String nextRunDate,
    String? note,
  }) async {
    await ref
        .read(recurringRepositoryProvider)
        .createRecurringRule(
          walletId: walletId,
          categoryId: categoryId,
          amount: amount,
          type: type,
          frequency: frequency,
          nextRunDate: nextRunDate,
          note: note,
        );
    ref.invalidateSelf();
  }

  Future<void> deleteRecurringRule(String id) async {
    await ref.read(recurringRepositoryProvider).deleteRecurringRule(id);
    ref.invalidateSelf();
  }
}
