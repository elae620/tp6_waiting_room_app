# AI — Utilisation de l'intelligence artificielle

## Informations générales

- **Projet :** `waiting_room_app` — application Flutter de gestion d'une salle d'attente.
- **TP :** TP6 — Géolocalisation, persistance locale, fonctionnement hors ligne, synchronisation et gestion avancée de la file d'attente.
- **Agent IA utilisé :** ChatGPT (GPT-6).
- **Langue des échanges :** principalement français.
- **Méthode de travail :** accompagnement étape par étape, analyse du code existant, proposition de modifications, explications et correction des erreurs.

## Objectif de l'utilisation de l'IA

ChatGPT a été utilisé comme assistant pédagogique pour accompagner la réalisation du TP6. Il a aidé à comprendre les fonctionnalités demandées, à adapter le code existant et à résoudre les difficultés rencontrées pendant le développement.

L'objectif était de faire évoluer l'application Waiting Room sans recommencer le projet depuis zéro.

## Principales fonctionnalités réalisées

- Intégration de la géolocalisation GPS.
- Surveillance de la connexion Internet.
- Persistance locale des clients avec SQLite.
- Synchronisation des données locales avec Supabase.
- Fonctionnement hors ligne avec synchronisation au retour d'Internet.
- Gestion des états de l'application avec Provider et ChangeNotifier.
- Réception des changements en temps réel avec Supabase Realtime.
- Pagination de la liste des clients.

## Nature de l'assistance fournie

L'IA a aidé à :

- Examiner les fichiers existants avant modification.
- Proposer du code complet et corrigé pour certains fichiers Dart.
- Expliquer les classes, méthodes et services utilisés.
- Adapter les nouvelles fonctionnalités à l'architecture existante.
- Identifier et corriger les erreurs rencontrées.
- Proposer des commandes de vérification : `dart format`, `flutter analyze` et `flutter test`.
- Guider les tests pratiques de l'application.

## Résultat

Les modifications ont été intégrées au projet et les vérifications ont été effectuées.

Tous les tests réalisés ont réussi, notamment les tests de fonctionnement hors ligne, de synchronisation, de gestion des clients et de pagination.

 Questions et demandes formulées pendant l'accompagnement

Les principales demandes adressées à ChatGPT étaient :

Aider à réaliser le TP Flutter étape par étape.

Examiner les fichiers existants avant de proposer des modifications.

Fournir le code complet corrigé de QueueProvider.

Adapter le code de l'interface waiting_room_app.dart.

Expliquer comment intégrer la pagination.

Vérifier les modifications avec flutter analyze.

Expliquer les erreurs rencontrées pendant les tests.

Corriger le fonctionnement de l'ajout en mode hors ligne.

Conserver les fonctionnalités déjà réalisées sans recommencer le projet.

L'accompagnement a été réalisé progressivement, en tenant compte des résultats fournis après chaque étape.

6. Difficultés rencontrées

Erreur de connexion Supabase en mode hors ligne

Pendant le test de l'ajout sans Internet, l'application a affiché :

SocketException: Connection refused

Cette erreur indiquait que la communication avec le serveur distant avait échoué.

La correction a consisté à effectuer d'abord l'enregistrement dans SQLite, puis à lancer la synchronisation Supabase en arrière-plan.

Dépendance entre GPS et ajout d'un client

La récupération de la position GPS ne devait pas empêcher l'ajout d'un client lorsque la position était indisponible.

Une correction a été apportée pour gérer séparément les erreurs GPS et conserver la possibilité d'enregistrer le client localement.

Adaptation de la pagination

La pagination devait être adaptée à l'architecture existante, qui utilise SQLite et Supabase directement dans QueueProvider.

Une logique de pagination locale a donc été mise en place, avec un chargement initial de 20 clients et un chargement supplémentaire lors du défilement.

Précautions prises

Conserver les fonctionnalités déjà terminées.

Maintenir la cohérence entre les colonnes SQLite et Supabase.

Séparer l'enregistrement local de la synchronisation distante.

Éviter les doublons pendant la synchronisation et les événements Realtime.

Vérifier les modifications avec les outils Flutter.

7. Vérifications et résultats des tests

Les commandes utilisées pour contrôler le projet sont :

dart format lib/queue_provider.dart
dart format lib/waiting_room_app.dart
flutter analyze
flutter test
flutter run

Résultat global : tous les tests réalisés ont réussi.

Les vérifications ont notamment couvert :

Le démarrage de l'application.

L'ajout d'un client avec Internet.

L'enregistrement et la récupération des données.

La suppression d'un client.

Le passage au client suivant avec Next Client.

L'ajout d'un client sans connexion Internet.

La conservation du client dans SQLite en mode hors ligne.

La synchronisation du client après le retour d'Internet.

Le chargement progressif des clients avec la pagination.

La gestion des changements Realtime et la prévention des doublons.

La commande flutter analyze a également indiqué :

No issues found!

Les tests automatisés exécutés avec flutter test ont réussi.

8. Concepts appris ou mobilisés

Flutter : développement d'une application multiplateforme.

Provider / ChangeNotifier : gestion et partage de l'état.

SQLite : stockage local et persistance des données.

Supabase : base de données distante et synchronisation.

connectivity_plus : surveillance de la connectivité réseau.

Géolocalisation : récupération de la latitude et de la longitude.

Programmation asynchrone : utilisation de async, await et Future.

Realtime : réception des changements distants.

Pagination : chargement progressif des données.

Débogage : analyse des erreurs et vérification progressive du code.
