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
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal harus lebih dari 0')),
      );
      return;
    }

    Navigator.of(
      context,
    ).pop({'walletId': _selectedWalletId!, 'amount': amount});
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletListProvider);

    return AlertDialog(
      title: Text(
        widget.isDeposit ? 'Setor ke Tabungan' : 'Tarik dari Tabungan',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.isDeposit
                    ? 'Setor ke: ${widget.goalTitle}'
                    : 'Tarik dari: ${widget.goalTitle}\nTerkumpul: Rp ${widget.currentAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),
            walletsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Gagal memuat dompet: $e'),
              data: (wallets) => DropdownButtonFormField<String>(
                initialValue: _selectedWalletId,
                decoration: InputDecoration(
                  labelText: widget.isDeposit ? 'Dari Dompet' : 'Ke Dompet',
                  border: const OutlineInputBorder(),
                ),
                items: wallets
                    .map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(
                          '${w.name} (Rp ${w.balance.toStringAsFixed(0)})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedWalletId = v),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Nominal (Rp)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isDeposit ? 'Setor' : 'Tarik'),
        ),
      ],
    );
  }
}
