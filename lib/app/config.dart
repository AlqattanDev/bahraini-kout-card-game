class AppConfig {
  static const String workerUrl = String.fromEnvironment(
    'WORKER_URL',
    defaultValue: 'http://localhost:8787',
  );

  static String get wsUrl {
    final uri = Uri.parse(workerUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.host}:${uri.port}';
  }
}
