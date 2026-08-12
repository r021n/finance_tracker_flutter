import "package:flutter/material.dart";
import "package:flutter/services.dart";

class AddEditSavingsGoalDialog extends StatefulWidget {
  const AddEditSavingsGoalDialog({
    super.key,
    this.initialTitle,
    this.initialTargetAmount,
    this.initialTargetDate,
  });

  final String? initialTitle;
  final double? initialTargetAmount;
  final String? initialTargetDate;

  @override
  State<AddEditSavingsGoalDialog> createState() =>
      _AddEditSavingsGoalDialogState();
}

class _AddEditSavingsGoalDialogState extends State<AddEditSavingsGoalDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _amountController = TextEditingController(
      text: widget.initialTargetAmount?.toStringAsFixed(0) ?? '',
    );
    if (widget.initialTargetDate != null) {
      _targetDate = DateTime.tryParse(widget.initialTargetDate!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? get _formattedTargetDate {
    if (_targetDate == null) return null;
    return '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Judul harus diisi")));
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal target harus lebih dari 0')),
      );
      return;
    }

    Navigator.of(context).pop({
      'title': title,
      'targetAmount': amount,
      'targetDate': _formattedTargetDate,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialTitle != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Target Tabungan' : 'Target Tabungan Baru'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Judul',
                hintText: 'Contoh: Dana Liburan',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
