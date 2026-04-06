import 'package:flutter/material.dart';

class RandomKeyButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final double? height;
  final double? width;

  const RandomKeyButton({
    Key? key,
    required this.onPressed,
    this.label = 'Random',
    this.height,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        fixedSize: width != null || height != null
            ? Size(width ?? double.infinity, height ?? double.infinity)
            : null,
      ),
      child: Text(label),
    );
  }
}