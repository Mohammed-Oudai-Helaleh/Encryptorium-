import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyButton extends StatelessWidget {
  final String data;
  final String message;

  const CopyButton({
    Key? key,
    required this.data,
    this.message = 'Copied to clipboard!',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.copy, size: 20),
      onPressed: data.isNotEmpty
          ? () {
        Clipboard.setData(ClipboardData(text: data));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
          : null,
      tooltip: 'Copy',
    );
  }
}