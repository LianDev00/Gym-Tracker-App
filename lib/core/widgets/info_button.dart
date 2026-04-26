import 'package:flutter/material.dart';
import '../theme/glass_kit.dart';

class InfoButton extends StatelessWidget {
  const InfoButton({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: 'Información',
      onPressed: () => showGlassDialog<void>(
        context: context,
        builder: (ctx) => GlassDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 8),
              Text('Información'),
            ],
          ),
          content: Text(text, style: const TextStyle(height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}
