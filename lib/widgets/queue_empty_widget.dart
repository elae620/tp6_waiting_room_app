import 'package:flutter/material.dart';

/// Widget affiché lorsque la file d'attente est vide.
class QueueEmptyWidget extends StatelessWidget {
  const QueueEmptyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          const Text(
            'No clients in the queue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add a client to get started.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
