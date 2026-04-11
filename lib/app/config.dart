class AppConfig {
  static const String workerUrl = String.fromEnvironment(
    'WORKER_URL',
    defaultValue: 'http://localhost:8787',
  );

  static String get wsUrl {
    final uri = Uri.parse(workerUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final defaultPort = scheme == 'wss' ? 443 : 80;
    final port = uri.port > 0 && uri.port != defaultPort ? ':${uri.port}' : '';
    return '$scheme://${uri.host}$port';
  }
}
