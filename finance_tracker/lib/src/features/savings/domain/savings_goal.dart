import "package:freezed_annotation/freezed_annotation.dart";

part "savings_goal.freezed.dart";
part "savings_goal.g.dart";

@freezed
abstract class SavingsGoal with _$SavingsGoal {
  const SavingsGoal._();

  const factory SavingsGoal({
    required String id,
    required String title,
    required double targetAmount,
    @Default(0.0) double currentAmount,
    String? targetDate,
    String? createdAt,
  }) = _SavingsGoal;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) =>
      _$SavingsGoalFromJson(json);

  double get progressPercent =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  double get remaining => targetAmount - currentAmount;
}
