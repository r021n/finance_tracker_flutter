import 'package:flutter/material.dart';

class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onKeyPressed,
    this.onBackspace,
    this.onDone,
  });

  final ValueChanged<String> onKeyPressed;
  final VoidCallback? onBackspace;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        _buildRow(['4', '5', '6']),
        _buildRow(['7', '8', '9']),
        _buildRow(['.', '0', '<']),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      children: [
        for (final key in keys)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: AspectRatio(
                aspectRatio: 2,
                child: ElevatedButton(
                  onPressed: () {
                    if (key == '<') {
                      onBackspace?.call();
                    } else {
                      onKeyPressed(key);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: key == '<'
                      ? const Icon(Icons.backspace_outlined)
                      : Text(key, style: const TextStyle(fontSize: 24)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
