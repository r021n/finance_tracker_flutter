import "package:freezed_annotation/freezed_annotation.dart";

part "wallet.freezed.dart";
part "wallet.g.dart";

enum WalletType { cash, bank, eWallet }

@freezed
abstract class Wallet with _$Wallet {
  const Wallet._();

  const factory Wallet({
    required String id,
    required String name,
    required WalletType type,
    @Default(0.0) double balance,
    String? icon,
    String? color,
    String? createdAt,
  }) = _Wallet;

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);
}
