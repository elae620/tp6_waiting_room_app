import 'package:flutter/material.dart';
import '../models/app_connectivity.dart';

class OfflineBanner extends StatelessWidget {
  final AppConnectivity status;

  const OfflineBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    // Ne rien afficher si la connexion est disponible
    if (status == AppConnectivity.online) {
      return const SizedBox.shrink();
    }

    // Déterminer le message et la couleur selon l'état
    final (message, color) = switch (status) {
      AppConnectivity.offline => ('No network connection', Colors.red),

      AppConnectivity.backendUnavailable => (
        'Waiting-room server unavailable',
        Colors.orange,
      ),

      AppConnectivity.checking => ('Checking connection...', Colors.blue),

      AppConnectivity.online => ('Connected', Colors.green),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: color,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
