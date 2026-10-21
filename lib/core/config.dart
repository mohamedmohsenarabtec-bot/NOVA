abstract final class Config {
  static const name = String.fromEnvironment('APP_NAME', defaultValue: 'NOVA');
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static bool get configured =>
      Uri.tryParse(url)?.hasScheme == true && key.isNotEmpty;
}
