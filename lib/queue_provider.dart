import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'geolocation_service.dart';
import 'local_queue_service.dart';
import 'models/client.dart';
import 'models/queue_state.dart';

/// Gestionnaire principal de la file d'attente.
class QueueProvider extends ChangeNotifier {
  final SupabaseClient _supabase;
  final LocalQueueService _localDb;
  final GeolocationService _geoService;

  // Clients actuellement affichés dans l'interface.
  List<Client> _clients = [];

  List<Client> get clients => List.unmodifiable(_clients);

  // État de la file d'attente.
  QueueState _queueState = QueueState.initial;

  QueueState get queueState => _queueState;

  // Erreur de synchronisation.
  String? _syncError;

  /// Message destiné à l'interface ; les détails techniques restent dans les logs.
  String? get syncError => _syncError == null
      ? null
      : 'Les clients non synchronisés sont conservés sur cet appareil. '
          'Ils seront envoyés dès que Supabase sera accessible.';

  // Écouteurs des événements.
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // Gestion de la synchronisation.
  bool _syncing = false;
  bool _syncRequested = false;
  bool _disposed = false;

  // Pagination.
  static const int _pageSize = 20;

  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;

  bool get isLoadingMore => _isLoadingMore;

  // Constructeur.
  QueueProvider({
    SupabaseClient? supabase,
    LocalQueueService? localDb,
    GeolocationService? geoService,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _localDb = localDb ?? LocalQueueService(),
       _geoService = geoService ?? GeolocationService();

  /// Modifie l'état et notifie l'interface.
  void _setQueueState(QueueState state, {bool notifyIfUnchanged = false}) {
    if (_disposed) return;

    final changed = _queueState != state;
    if (!changed && !notifyIfUnchanged) return;

    _queueState = state;
    notifyListeners();
  }

  // ============================================================
  // 1. INITIALISATION
  // ============================================================

  /// Initialise le provider.
  Future<void> initialize() async {
    if (_disposed) return;

    _setQueueState(QueueState.loading);

    try {
      // Charger la première page depuis SQLite.
      await _reloadFromLocal(resetPagination: true);

      if (_disposed) return;

      // Démarrer l'écoute Realtime.
      _listen();

      // Surveiller la connexion Internet.
      _connSub = Connectivity().onConnectivityChanged.listen((results) {
        if (!results.contains(ConnectivityResult.none)) {
          unawaited(_syncLocalToRemote());
        }
      });

      // Synchroniser les clients locaux avec Supabase.
      await _syncLocalToRemote();
    } catch (e, stackTrace) {
      debugPrint('Initialization error: $e');
      debugPrintStack(stackTrace: stackTrace);

      _setQueueState(QueueState.error);
    }
  }

  // ============================================================
  // 2. CHARGEMENT LOCAL ET PAGINATION
  // ============================================================

  /// Recharge les clients depuis SQLite.
  ///
  /// Par défaut, conserve le nombre de pages déjà chargées.
  /// Si resetPagination est true, revient à la première page.
  Future<void> _reloadFromLocal({bool resetPagination = false}) async {
    final rows = await _localDb.getClients();

    // Convertir les données SQLite en objets Client.
    final allClients = rows.map(Client.fromMap).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (_disposed) return;

    if (resetPagination) {
      _currentPage = 0;
    }

    // Éviter de conserver une page qui n'existe plus.
    if (allClients.isEmpty) {
      _currentPage = 0;
    } else {
      final maxPage = (allClients.length - 1) ~/ _pageSize;

      if (_currentPage > maxPage) {
        _currentPage = maxPage;
      }
    }

    // Nombre de clients qui doivent être visibles.
    final visibleCount = ((_currentPage + 1) * _pageSize).clamp(
      0,
      allClients.length,
    );

    // Afficher uniquement les pages déjà chargées.
    _clients = allClients.take(visibleCount).toList();

    // Vérifier s'il reste des clients à charger.
    _hasMore = visibleCount < allClients.length;

    _setQueueState(
      _clients.isEmpty ? QueueState.empty : QueueState.loaded,
      // Les données ont été rechargées : notifier même si l'état reste loaded.
      notifyIfUnchanged: true,
    );
  }

  /// Actualise manuellement la file d'attente.
  Future<void> refreshQueue() async {
    if (_disposed ||
        _queueState == QueueState.loading ||
        _queueState == QueueState.refreshing) {
      return;
    }

    _setQueueState(QueueState.refreshing);

    try {
      // Revenir à la première page.
      _currentPage = 0;
      _hasMore = true;

      await _reloadFromLocal(resetPagination: true);

      if (_disposed) return;

      // Synchroniser les données avec Supabase.
      await _syncLocalToRemote();
    } catch (e, stackTrace) {
      debugPrint('Refresh error: $e');
      debugPrintStack(stackTrace: stackTrace);

      _setQueueState(QueueState.error);
    }
  }

  /// Charge les 20 clients suivants depuis SQLite.
  Future<void> loadMore() async {
    if (_disposed || _isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    _setQueueState(QueueState.loadingMore);

    try {
      // Récupérer tous les clients locaux.
      final rows = await _localDb.getClients();

      final allClients = rows.map(Client.fromMap).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (_disposed) return;

      // Le prochain chargement commence après les clients visibles.
      final startIndex = _clients.length;

      if (startIndex >= allClients.length) {
        _hasMore = false;
        return;
      }

      final endIndex = (startIndex + _pageSize).clamp(0, allClients.length);

      final nextPage = allClients.sublist(startIndex, endIndex);

      // Éviter les doublons.
      final existingIds = _clients.map((c) => c.id).toSet();

      final uniqueClients = nextPage.where(
        (client) => !existingIds.contains(client.id),
      );

      _clients.addAll(uniqueClients);

      // Mettre à jour le numéro de page.
      if (_clients.isNotEmpty) {
        _currentPage = (_clients.length - 1) ~/ _pageSize;
      }

      // Vérifier s'il reste d'autres clients.
      _hasMore = endIndex < allClients.length;

      debugPrint('Pagination: ${_clients.length} clients chargés.');
    } catch (e, stackTrace) {
      debugPrint('Load more error: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isLoadingMore = false;

      if (!_disposed) {
        _setQueueState(_clients.isEmpty ? QueueState.empty : QueueState.loaded);
      }
    }
  }

  // ============================================================
  // 3. GESTION DES INSERTIONS REALTIME
  // ============================================================

  /// Gère un nouveau client reçu par Realtime.
  void handleRealtimeInsert(Client client) {
    if (_disposed) return;

    // Vérifier si le client existe déjà.
    final exists = _clients.any((c) => c.id == client.id);

    if (exists) return;

    // Ajouter uniquement si la page actuellement affichée
    // dispose encore d'une place.
    if (_clients.length < (_currentPage + 1) * _pageSize) {
      _clients.add(client);

      _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (_queueState == QueueState.empty) {
        _queueState = QueueState.loaded;
      }

      notifyListeners();
    } else {
      // Le client sera récupéré lors du prochain chargement.
      _hasMore = true;
      notifyListeners();
    }
  }

  // ============================================================
  // 4. ÉCOUTE REALTIME SUPABASE
  // ============================================================

  /// Écoute les changements de la table clients.
  void _listen() {
    _sub = _supabase
        .from('clients')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .listen(
          (rows) async {
            try {
              // Identifiants des clients présents dans Supabase.
              final remoteIds = rows.map((row) => row['id'].toString()).toSet();

              // Insérer ou actualiser les clients reçus.
              for (final row in rows) {
                await _localDb.insertClientLocally({
                  'id': row['id'].toString(),
                  'name': row['name'],
                  'lat': row['lat'],
                  'lng': row['lng'],
                  'created_at': row['created_at'].toString(),
                  'is_synced': 1,
                });
              }

              // Récupérer les clients enregistrés localement.
              final localClients = await _localDb.getClients();

              // Supprimer les clients synchronisés qui n'existent
              // plus dans Supabase.
              for (final client in localClients) {
                if (client['is_synced'] == 1 &&
                    !remoteIds.contains(client['id'].toString())) {
                  await _localDb.deleteClient(client['id'].toString());
                }
              }

              if (_disposed) return;

              // Actualiser les données sans perdre les pages chargées.
              await _reloadFromLocal();
            } catch (e, stackTrace) {
              debugPrint('Realtime processing error: $e');
              debugPrintStack(stackTrace: stackTrace);

              _setQueueState(QueueState.error);
            }
          },
          onError: (e) {
            debugPrint('Realtime stream error: $e');
          },
        );
  }

  // ============================================================
  // 5. SYNCHRONISATION SQLITE VERS SUPABASE
  // ============================================================

  /// Synchronise les clients non synchronisés vers Supabase.
  Future<void> _syncLocalToRemote() async {
    if (_disposed) return;

    // Si une synchronisation est déjà en cours,
    // demander une nouvelle vérification à la fin.
    if (_syncing) {
      _syncRequested = true;
      return;
    }

    _syncing = true;

    try {
      do {
        _syncRequested = false;

        // Récupérer les clients qui ne sont pas synchronisés.
        final unsynced = await _localDb.getUnsyncedClients();

        for (final client in unsynced) {
          if (_disposed) return;

          try {
            final localId = client['id'] as String;

            // Préparer les données pour Supabase.
            final remote = Map<String, dynamic>.from(client)
              ..remove('id')
              ..remove('is_synced');

            // Insérer le client dans Supabase.
            final inserted = await _supabase
                .from('clients')
                .insert(remote)
                .select('id')
                .single();

            // Remplacer l'identifiant local par l'identifiant distant.
            await _localDb.replaceClientId(localId, inserted['id'].toString());

            _syncError = null;

            debugPrint('Client synchronized: $localId');
          } catch (e) {
            _syncError = e.toString();

            debugPrint('Sync failed for ${client['id']}: $e');
          }
        }
      } while (_syncRequested && !_disposed);

      if (_disposed) return;

      // Recharger les données après synchronisation.
      await _reloadFromLocal();

      // Actualiser l'interface pour afficher l'état de synchronisation.
      if (!_disposed) {
        notifyListeners();
      }
    } finally {
      _syncing = false;
    }
  }

  // ============================================================
  // 6. AJOUT D'UN CLIENT
  // ============================================================

  /// Ajoute un client localement puis lance sa synchronisation.

  /// Ajoute un client localement puis lance sa synchronisation.
  Future<void> addClient(String name) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty || _disposed) return;

    try {
      // 1. Essayer de récupérer la position GPS.
      double? latitude;
      double? longitude;

      try {
        debugPrint('ADD: Getting location...');

        final position = await _geoService.getCurrentPosition();

        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;

          debugPrint('Position GPS reçue : $latitude, $longitude');
        }
      } catch (e) {
        // Une erreur GPS ne doit pas empêcher l'ajout.
        debugPrint('GPS unavailable: $e');
      }

      if (_disposed) return;

      // 2. Générer un identifiant local.
      final id = const Uuid().v4();

      // 3. Enregistrer le client dans SQLite.
      // is_synced = 0 signifie qu'il n'est pas encore
      // synchronisé avec Supabase.
      await _localDb.insertClientLocally({
        'id': id,
        'name': trimmedName,
        'lat': latitude,
        'lng': longitude,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'is_synced': 0,
      });

      debugPrint('Client saved locally: $trimmedName');

      if (_disposed) return;

      // 4. Actualiser immédiatement la liste locale.
      await _reloadFromLocal();

      // 5. Tenter la synchronisation en arrière-plan.
      // Si Internet est indisponible, le client reste dans SQLite.
      unawaited(_syncLocalToRemote());
    } catch (e, stackTrace) {
      debugPrint('ADD FAILED: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  // ============================================================
  // 7. SUPPRESSION D'UN CLIENT
  // ============================================================

  /// Supprime un client localement et dans Supabase.
  Future<void> removeClient(String id) async {
    await _localDb.deleteClient(id);

    if (_disposed) return;

    // Actualiser la liste locale.
    await _reloadFromLocal();

    try {
      // Supprimer également le client dans Supabase.
      await _supabase.from('clients').delete().eq('id', id);
    } catch (e) {
      debugPrint('Remove failed (offline ?): $e');
    }
  }

  // ============================================================
  // 8. PASSAGE AU CLIENT SUIVANT (FIFO)
  // ============================================================

  /// Retire le premier client de la file.
  Future<void> nextClient() async {
    if (_clients.isEmpty || _disposed) return;

    // Le premier client est le plus ancien.
    await removeClient(_clients.first.id);
  }

  // ============================================================
  // 9. LIBÉRATION DES RESSOURCES
  // ============================================================

  @override
  void dispose() {
    _disposed = true;

    _sub?.cancel();
    _connSub?.cancel();

    super.dispose();
  }
}
