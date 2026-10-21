import 'dart:convert';

abstract final class Config {
  static const name = String.fromEnvironment('APP_NAME', defaultValue: 'NOVA');
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const emailRecoveryEnabled = bool.fromEnvironment(
    'AUTH_EMAIL_RECOVERY_ENABLED',
    defaultValue: false,
  );
  static bool get configured => ClientConfig.valid(url, key);
}

abstract final class ClientConfig {
  static bool valid(String url, String key) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path != '' && uri.path != '/') ||
        !(uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '::1'].contains(uri.host)))) {
      return false;
    }
    if (key.startsWith('sb_publishable_') && key.length > 25) return true;
    // Legacy anonymous JWTs are public too. Privileged keys must never initialize a client.
    try {
      final parts = key.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }
}
