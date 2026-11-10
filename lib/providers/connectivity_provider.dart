import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_connectivity.dart';
import '../services/connectivity_service.dart';

class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _service;

  StreamSubscription<bool>? _subscription;
  Timer? _debounceTimer;

  AppConnectivity _status = AppConnectivity.checking;

  bool _checkingBackend = false;
  bool _checkAgain = false;
  bool _disposed = false;

  ConnectivityProvider(this._service);

  AppConnectivity get status => _status;

  bool get isOnline => _status == AppConnectivity.online;

  // Initialiser la surveillance de la connexion
  Future<void> initialize() async {
    _subscription = _service.networkChanges.listen(
      _handleNetworkChange,
      onError: (_) => _setStatus(AppConnectivity.checking),
    );

    final connected = await _service.hasNetwork();

    if (_disposed) return;

    _handleNetworkChange(connected);
  }

  // Réagir aux changements de réseau
  void _handleNetworkChange(bool connected) {
    _debounceTimer?.cancel();

    if (!connected) {
      _setStatus(AppConnectivity.offline);
      return;
    }

    // Attendre 700 ms avant de vérifier Supabase
    _debounceTimer = Timer(const Duration(milliseconds: 700), _checkBackend);
  }

  // Vérifier la disponibilité de Supabase
  Future<void> _checkBackend() async {
    if (_disposed) return;

    if (_checkingBackend) {
      _checkAgain = true;
      return;
    }

    _checkingBackend = true;

    try {
      do {
        _checkAgain = false;

        final available = await _service.isSupabaseAvailable();

        if (_disposed) return;

        _setStatus(
          available
              ? AppConnectivity.online
              : AppConnectivity.backendUnavailable,
        );
      } while (_checkAgain && !_disposed);
    } finally {
      _checkingBackend = false;
    }
  }

  // Mettre à jour l'état et notifier les widgets
  void _setStatus(AppConnectivity newStatus) {
    if (_disposed || _status == newStatus) return;

    _status = newStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _subscription?.cancel();

    super.dispose();
  }
}
