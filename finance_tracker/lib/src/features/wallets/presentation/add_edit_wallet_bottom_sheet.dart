import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/utils/color_utils.dart";
import "../../../shared/constants/app_icons.dart";
import "../domain/wallet.dart";
import "../providers/wallet_providers.dart";

class AddEditWalletBottomSheet extends ConsumerStatefulWidget {
  const AddEditWalletBottomSheet({super.key, this.wallet});

  final Wallet? wallet;

  @override
  ConsumerState<AddEditWalletBottomSheet> createState() =>
      _AddEditWalletBottomSheetState();
}

class _AddEditWalletBottomSheetState
    extends ConsumerState<AddEditWalletBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;

  late WalletType _type;
  late String _icon;
  late String _color;

  bool get _isEdit => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    final w = widget.wallet;
    _nameController = TextEditingController(text: w?.name);
    _balanceController = TextEditingController(
      text: w == null ? "" : w.balance.toStringAsFixed(0),
    );
    _type = w?.type ?? WalletType.cash;
    _icon = w?.icon ?? "wallet";
    _color = w?.color ?? "#4CAF50";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(WalletListNotifierProvider.notifier);
  }
}
