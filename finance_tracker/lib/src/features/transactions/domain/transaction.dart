import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

enum TransactionType { income, expense }

@freezed
abstract class Transaction with _$Transaction {
  const Transaction._();

  const factory Transaction({
    required String id,
    required String walletId,
    String? categoryId,
    required double amount,
    required TransactionType type,
    required String transactionDate,
    String? note,
    String? createdAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}
