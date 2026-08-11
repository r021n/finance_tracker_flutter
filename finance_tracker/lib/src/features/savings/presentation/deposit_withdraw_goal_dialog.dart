import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../wallets/providers/wallet_providers.dart";

class DepositWithdrawGoalDialog extends ConsumerStatefulWidget {
  const DepositWithdrawGoalDialog({
    super.key,
    required this.goalTitle,
    required this.isDeposit,
    required this.currentAmount,
  });

  final String goalTitle;
  final bool isDeposit;
  final double currentAmount;

  @override
  ConsumerState<DepositWithdrawGoalDialog> createState() =>
      _DepositWithdrawGoalDialogState();
}

class _DepositWithdrawGoalDialogState
    extends ConsumerState<DepositWithdrawGoalDialog> {
  String? _selectedWalletId;
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet terlebih dahulu')),
      );
    }
    return;
  }
}
