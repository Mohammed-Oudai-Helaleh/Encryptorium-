import 'package:flutter/material.dart';
import 'package:encryptorium/custom/copy_button.dart';
import 'package:encryptorium/custom/error_text.dart';
import 'package:encryptorium/custom/my_text_field.dart';
import 'package:encryptorium/custom/random_key_button.dart';

class KeyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final String? errorText;
  final String note;
  final VoidCallback onRandom;
  final bool readOnly;

  const KeyField({
    Key? key,
    required this.label,
    required this.controller,
    required this.hintText,
    this.errorText,
    required this.note,
    required this.onRandom,
    this.readOnly = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MyTextField(
                hintText: hintText,
                controller: controller,
                margin: EdgeInsets.zero,
                readOnly: readOnly,
              ),
            ),
            const SizedBox(width: 8),
            RandomKeyButton(onPressed: onRandom),
            const SizedBox(width: 8),
            CopyButton(data: controller.text),
          ],
        ),
        ErrorText(message: errorText),
        const SizedBox(height: 4),
        Text(
          note,
          style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}