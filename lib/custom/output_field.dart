import 'package:flutter/material.dart';
import 'package:encryptorium/custom/copy_button.dart';
import 'package:encryptorium/custom/my_text_field.dart';

class OutputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool isFileMode;

  const OutputField({
    Key? key,
    required this.label,
    required this.controller,
    required this.hintText,
    this.isFileMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Output',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: MyTextField(
            hintText: hintText,
            controller: controller,
            height: isFileMode ? 80 : 150,
            maxLines: isFileMode ? 3 : 6,
            margin: EdgeInsets.zero,
            readOnly: true,
          ),
        ),
        if (controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CopyButton(data: controller.text),
              ],
            ),
          ),
      ],
    );
  }
}