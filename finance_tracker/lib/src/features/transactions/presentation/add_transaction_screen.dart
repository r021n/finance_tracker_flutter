import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/color_utils.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/constants/app_icons.dart';
import '../../wallets/providers/wallet_providers.dart';
import '../../categories/providers/category_providers.dart';
import '../domain/transaction.dart';
import '../providers/transaction_providers.dart';
import 'widgets/numeric_keypad.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.transaction});

  final Transaction? transaction;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TransactionType _type;
  String? _selectedWalletId;
  String? _selectedCategoryId;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String _amountText = '';
  final _noteController = TextEditingController();

  bool get _isEdit => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    if (t != null) {
      _type = t.type;
      _selectedWalletId = t.walletId;
      _selectedCategoryId = t.categoryId;
      _selectedDate = DateTime.parse(t.transactionDate);
      _selectedTime = TimeOfDay.fromDateTime(_selectedDate);
      _amountText = t.amount.toStringAsFixed(0);
      _noteController.text = t.note ?? '';
    } else {
      _type = TransactionType.expense;
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String get _formattedDate {
    return '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
  }

  double get _amount => double.tryParse(_amountText) ?? 0;

  void _onKeyPressed(String key) {
    setState(() {
      if (key == '.' && _amountText.contains('.')) return;
      if (key == '.' && _amountText.isEmpty) {
        _amountText = '0.';
        return;
      }
      _amountText += key;
    });
  }
}
