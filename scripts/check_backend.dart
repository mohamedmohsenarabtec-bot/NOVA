import 'dart:convert';
import 'dart:io';

import 'package:nova/core/config.dart';

import 'live_smoke.dart' show Api;

Future<void> main(List<String> args) async {
  final path = args.isEmpty ? 'config/local.json' : args.first;
  final config = jsonDecode(
    File(path).readAsStringSync().replaceFirst('\ufeff', ''),
  ) as Map<String, dynamic>;
  final url = config['SUPABASE_URL'] as String? ?? '';
  final key = config['SUPABASE_PUBLISHABLE_KEY'] as String? ?? '';
  if (!ClientConfig.valid(url, key)) {
    stderr.writeln('Invalid public configuration');
    exitCode = 1;
    return;
  }
  final api = Api(url, key);
  final report = <String, dynamic>{
    'checked_utc': DateTime.now().toUtc().toIso8601String(),
    'project_host': Uri.parse(url).host,
  };
  try {
    final response = await api.call('GET', '/auth/v1/settings');
    final settings = response.data as Map;
    report['auth_reachable'] = true;
    report['email_enabled'] = (settings['external'] as Map)['email'];
    report['email_confirmation_disabled'] =
        settings['mailer_autoconfirm'] == true;
    report['signup_disabled'] = settings['disable_signup'];
    final schema = await api.call(
      'POST',
      '/rest/v1/rpc/client_capabilities',
      body: {},
      allowFailure: true,
    );
    report['nova_schema_ready'] = schema.status == 200 && schema.data == 10;
    report['schema_probe_http'] = schema.status;
    if (schema.status >= 400) {
      report['schema_probe_code'] = schema.data is Map
          ? schema.data['code']
          : 'request_failed';
    }
    report['flows'] =
        'NOT TESTED: no accounts or data are created by this read-only check';
    if (report['nova_schema_ready'] != true) exitCode = 2;
  } catch (_) {
    report['connection_error'] = 'Could not complete read-only backend probes';
    exitCode = 1;
  } finally {
    api.client.close(force: true);
    Directory('docs/verification').createSync(recursive: true);
    File('docs/verification/backend-connection.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  }
}
