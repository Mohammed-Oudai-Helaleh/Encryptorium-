import 'package:flutter/material.dart';

class FilePickerButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FilePickerButton({Key? key, required this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.attach_file),
      onPressed: onPressed,
      tooltip: 'Pick a file',
    );
  }
}