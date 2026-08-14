import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_summary.freezed.dart';
part 'dashboard_summary.g.dart';

@freezed
abstract class DashboardSummary with _$DashboardSummary {
  const factory DashboardSummary({
    required double totalBalance,
    required double monthlyIncome,
    required double monthlyExpense,
  }) = _DashboardSummary;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      _$DashboardSummaryFromJson(json);
}

@freezed
abstract class DailyCashFlow with _$DailyCashFlow {
  const factory DailyCashFlow({
    required String date,
    required double income,
    required double expense,
  }) = _DailyCashFlow;

  factory DailyCashFlow.fromJson(Map<String, dynamic> json) =>
      _$DailyCashFlowFromJson(json);
}

@freezed
abstract class CategoryExpenseSummary with _$CategoryExpenseSummary {
  const factory CategoryExpenseSummary({
    required String categoryName,
    required String? categoryColor,
    required double total,
  }) = _CategoryExpenseSummary;

  factory CategoryExpenseSummary.fromJson(Map<String, dynamic> json) =>
      _$CategoryExpenseSummaryFromJson(json);
}
