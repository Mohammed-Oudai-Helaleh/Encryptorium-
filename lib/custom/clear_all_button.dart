import 'package:flutter/material.dart';

class ClearAllButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ClearAllButton({Key? key, required this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.clear_all),
      onPressed: onPressed,
      tooltip: 'Clear all fields',
    );
  }
}