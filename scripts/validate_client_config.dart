import 'dart:convert';
import 'dart:io';

import 'package:nova/core/config.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run scripts/validate_client_config.dart config/local.json',
    );
    exitCode = 64;
    return;
  }
  try {
    final data = jsonDecode(
      File(args.single).readAsStringSync().replaceFirst('\ufeff', ''),
    ) as Map<String, dynamic>;
    if (!ClientConfig.valid(
      data['SUPABASE_URL'] as String? ?? '',
      data['SUPABASE_PUBLISHABLE_KEY'] as String? ?? '',
    )) {
      throw const FormatException();
    }
    stdout.writeln(
      'Public client configuration is valid. No private credentials printed.',
    );
  } catch (_) {
    stderr.writeln(
      'Invalid configuration. Use the project root HTTPS URL and a publishable or legacy anon key; privileged keys are forbidden.',
    );
    exitCode = 1;
  }
}
