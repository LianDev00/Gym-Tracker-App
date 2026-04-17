import 'package:flutter/material.dart';

class InfoButton extends StatelessWidget {
  const InfoButton({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: 'Información',
      onPressed: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.info_outline),
          content: Text(text, style: const TextStyle(height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}
