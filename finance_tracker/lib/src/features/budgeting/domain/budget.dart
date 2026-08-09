import "package:freezed_annotation/freezed_annotation.dart";

part "budget.freezed.dart";
part "budget.g.dart";

@freezed
abstract class Budget with _$Budget {
  const Budget._();

  const factory Budget({
    required String id,
    required String categoryId,
    required double amountLimit,
    required String monthYear,
    String? createdAt,
  }) = _Budget;

  factory Budget.fromJson(Map<String, dynamic> json) => _$BudgetFromJson(json);
}

@freezed
abstract class BudgetWithProgress with _$BudgetWithProgress {
  const BudgetWithProgress._();

  const factory BudgetWithProgress({
    required Budget budget,
    required String categoryName,
    String? categoryIcon,
    String? categoryColor,
    required double spent,
  }) = _BudgetWithProgress;

  double get usagePercent =>
      budget.amountLimit > 0 ? spent / budget.amountLimit : 0.0;

  double get remaining => budget.amountLimit - spent;
}
