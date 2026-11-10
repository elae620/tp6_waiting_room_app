/// États possibles de la file d'attente.
enum QueueState {
  initial,
  loading,
  loaded,
  empty,
  refreshing,
  loadingMore,
  error,
}
