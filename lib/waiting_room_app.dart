import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'queue_provider.dart';
import 'providers/connectivity_provider.dart';

import 'models/queue_state.dart';

import 'widgets/offline_banner.dart';
import 'widgets/loading_widget.dart';
import 'widgets/queue_empty_widget.dart';

/// Widget racine de l'application Waiting Room.
class WaitingRoomApp extends StatelessWidget {
  const WaitingRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waiting Room',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const WaitingRoomPage(),
    );
  }
}

/// Page principale affichant la file d'attente.
class WaitingRoomPage extends StatefulWidget {
  const WaitingRoomPage({super.key});

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  final TextEditingController _controller = TextEditingController();

  // Contrôleur permettant de détecter le défilement de la liste.
  final ScrollController _scrollController = ScrollController();

  /// Ajouter un client.
  Future<void> _add() async {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a client name.')));
      return;
    }

    _controller.clear();

    try {
      await context.read<QueueProvider>().addClient(name);
    } catch (e, stackTrace) {
      debugPrint('Add client error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to add client: $e')));
    }
  }

  /// Détecter l'arrivée près de la fin de la liste.
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    // Charger la page suivante lorsqu'il reste moins de 200 pixels.
    if (position.extentAfter < 200) {
      context.read<QueueProvider>().loadMore();
    }
  }

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Room'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh queue',
            onPressed: () {
              context.read<QueueProvider>().refreshQueue();
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // Bandeau de connexion Internet et Supabase.
          Consumer<ConnectivityProvider>(
            builder: (context, connectivity, child) {
              return OfflineBanner(status: connectivity.status);
            },
          ),

          // Contenu principal.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Champ de saisie et bouton Add.
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Enter name',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _add(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _add, child: const Text('Add')),
                    ],
                  ),

                  // Erreur de synchronisation Supabase.
                  Consumer<QueueProvider>(
                    builder: (context, provider, child) {
                      final error = provider.syncError;

                      if (error == null) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Affichage de la file selon son état.
                  Expanded(
                    child: Consumer<QueueProvider>(
                      builder: (context, provider, child) {
                        switch (provider.queueState) {
                          case QueueState.initial:
                          case QueueState.loading:
                            return const LoadingWidget(
                              message: 'Loading clients...',
                            );

                          case QueueState.empty:
                            return const QueueEmptyWidget();

                          case QueueState.error:
                            return const Center(
                              child: Text(
                                'Unable to load the queue.',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                            );

                          case QueueState.loaded:
                          case QueueState.refreshing:
                          case QueueState.loadingMore:
                            return Stack(
                              children: [
                                // Liste des clients avec pagination.
                                ListView.builder(
                                  controller: _scrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount:
                                      provider.clients.length +
                                      (provider.hasMore ? 1 : 0),
                                  itemBuilder: (context, i) {
                                    // Dernier élément : indicateur de pagination.
                                    if (i >= provider.clients.length) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }

                                    final client = provider.clients[i];

                                    final location =
                                        client.lat != null && client.lng != null
                                        ? 'Lat: ${client.lat}, '
                                              'Lng: ${client.lng}'
                                        : 'Position indisponible';

                                    return Card(
                                      child: ListTile(
                                        title: Text(client.name),
                                        subtitle: Text(
                                          '${client.createdAt.toString().split(' ')[0]}\n'
                                          '$location',
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          tooltip: 'Delete client',
                                          onPressed: () {
                                            provider.removeClient(client.id);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // Indicateur pendant l'actualisation.
                                if (provider.queueState ==
                                    QueueState.refreshing)
                                  const Align(
                                    alignment: Alignment.topCenter,
                                    child: LinearProgressIndicator(),
                                  ),

                                // Indicateur pendant le chargement suivant.
                                if (provider.isLoadingMore)
                                  const Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                              ],
                            );
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bouton Next Client.
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<QueueProvider>().nextClient();
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next Client'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
