import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/utils/color_utils.dart";
import "../../../../core/utils/currency_formatter.dart";
import "../../../../shared/constants/app_icons.dart";
import "../../domain/wallet.dart";

class WalletCard extends ConsumerWidget {
  const WalletCard({super.key, required this.wallet, this.onTap});

  final Wallet wallet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorFromHex(wallet.color);
    final typeLabel = switch (wallet.type) {
      WalletType.cash => "Cash",
      WalletType.bank => "Bank",
      WalletType.eWallet => "E-Wallet",
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(iconFromName(wallet.icon), color: color),
        ),
        title: Text(wallet.name),
        subtitle: Text(typeLabel),
        trailing: Text(
          formatCurrency(wallet.balance),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
