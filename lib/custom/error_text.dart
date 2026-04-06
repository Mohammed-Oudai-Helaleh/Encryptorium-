import 'package:flutter/material.dart';

class ErrorText extends StatelessWidget {
  final String? message;

  const ErrorText({Key? key, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 12),
      child: Text(
        message!,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }
}