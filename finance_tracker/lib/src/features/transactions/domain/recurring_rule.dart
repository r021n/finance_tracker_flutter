import 'package:freezed_annotation/freezed_annotation.dart';

import 'transaction.dart';

part 'recurring_rule.freezed.dart';
part 'recurring_rule.g.dart';

enum RecurringFrequency { daily, weekly, monthly }

@freezed
abstract class RecurringRule with _$RecurringRule {
  const RecurringRule._();

  const factory RecurringRule({
    required String id,
    required String walletId,
    String? categoryId,
    required double amount,
    required TransactionType type,
    required RecurringFrequency frequency,
    required String nextRunDate,
    String? note,
  }) = _RecurringRule;

  factory RecurringRule.fromJson(Map<String, dynamic> json) =>
      _$RecurringRuleFromJson(json);
}
