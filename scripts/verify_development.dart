// Verifies existing development identities; never resets or deletes accounts.
// Supply the password via ephemeral NOVA_DEVELOPMENT_PASSWORD or secure stdin.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:supabase/supabase.dart';
import 'package:nova/core/config.dart';

import 'browser_probe.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    throw ArgumentError('config file and two development emails required');
  }
  final config = jsonDecode(
    File(args[0]).readAsStringSync().replaceFirst('\ufeff', ''),
  ) as Map;
  final url = config['SUPABASE_URL'] as String;
  final key = config['SUPABASE_PUBLISHABLE_KEY'] as String;
  if (!ClientConfig.valid(url, key)) {
    throw StateError('Invalid public configuration');
  }
  final password = Platform.environment['NOVA_DEVELOPMENT_PASSWORD'];
  if (password == null || password.length < 12) {
    throw StateError('Supply development password in process environment only');
  }
  final clients = List.generate(
    2,
    (_) => SupabaseClient(
      url,
      key,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
  );
  final results = <Map<String, String>>[];
  Future<void> check(String name, Future<void> Function() action) async {
    try {
      await action();
      results.add({'flow': name, 'status': 'PASS'});
      stdout.writeln('PASS: $name');
    } catch (error) {
      results.add({
        'flow': name,
        'status': 'INCOMPLETE',
        'reason': error.runtimeType.toString(),
      });
      stderr.writeln('INCOMPLETE: $name (${error.runtimeType})');
      exitCode = 1;
    }
  }

  try {
    for (var i = 0; i < clients.length; i++) {
      await clients[i].auth.signInWithPassword(
        email: args[i + 1],
        password: password,
      );
      await clients[i].realtime.setAuth(
        clients[i].auth.currentSession!.accessToken,
      );
    }
    final conversation =
        (await clients.first.from('conversations').select('id').limit(1))
                .single['id']
            as String;
    await check('both existing accounts have persisted distinct profiles and no staff roles', () async {
      final names = <String>{};
      for (final client in clients) {
        final profile = await client
            .from('profiles')
            .select('id,display_name,onboarding_complete')
            .single();
        if (profile['onboarding_complete'] != true) {
          throw StateError('Onboarding missing');
        }
        names.add(profile['display_name'] as String);
        if ((await client.from('staff_roles').select('role')).isNotEmpty) {
          throw StateError('Unexpected staff role');
        }
      }
      if (names.length != 2) throw StateError('Profiles not distinguishable');
    });
    for (var i = 0; i < 2; i++) {
      await check('persistent realtime message delivered to participant ${i + 1}', () async {
        final subscribed = Completer<void>();
        final delivered = Completer<void>();
        final body =
            'Connection check ${DateTime.now().microsecondsSinceEpoch}';
        final channel = clients[i]
            .channel(
              'development-verification-$i-${DateTime.now().microsecondsSinceEpoch}',
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: conversation,
              ),
              callback: (p) {
                if (p.newRecord['body'] == body && !delivered.isCompleted) {
                  delivered.complete();
                }
              },
            )
            .onSystemEvents((event) {
              if (event is Map &&
                  event['extension'] == 'postgres_changes' &&
                  event['status'] == 'ok' &&
                  !subscribed.isCompleted) {
                subscribed.complete();
              }
            })
            .subscribe((status, error) {
              if (error != null && !subscribed.isCompleted) {
                subscribed.completeError(
                  StateError('Realtime subscription error'),
                );
              }
            });
        try {
          await subscribed.future.timeout(const Duration(seconds: 25));
          await clients[1 - i].rpc(
            'send_message',
            params: {'conversation': conversation, 'body': body},
          );
          await delivered.future.timeout(const Duration(seconds: 35));
          final rows = await clients[i]
              .from('messages')
              .select('id')
              .eq('conversation_id', conversation)
              .eq('body', body);
          if (rows.length != 1) throw StateError('Message not persisted');
        } finally {
          await clients[i].removeChannel(channel);
        }
      });
    }
    if (args.contains('--verify-password-change')) {
      await check('real Auth password update works and original development password is restored', () async {
        final client = clients.first;
        final temporary =
            'Nv!${base64UrlEncode(List.generate(30, (_) => Random.secure().nextInt(256)))}9a';
        await client.auth.signInWithPassword(
          email: args[1],
          password: password,
        );
        try {
          await client.auth.updateUser(UserAttributes(password: temporary));
          await client.auth.signInWithPassword(
            email: args[1],
            password: temporary,
          );
        } finally {
          await client.auth.updateUser(UserAttributes(password: password));
        }
        await client.auth.signInWithPassword(
          email: args[1],
          password: password,
        );
      });
    }
    final browserUrl = args
        .where((a) => a.startsWith('--browser-url='))
        .firstOrNull;
    if (browserUrl != null) {
      await check(
        'published browser locale/theme persistence, login and persistent chat',
        () => BrowserProbe.verify(
          url: browserUrl.substring(14),
          email: args[1],
          password: password,
          conversationId: conversation,
          expectedMessage: 'NOVA owner test B',
        ),
      );
    }
    await check('both accounts can logout and login again', () async {
      for (var i = 0; i < 2; i++) {
        await clients[i].auth.signOut();
        await clients[i].auth.signInWithPassword(
          email: args[i + 1],
          password: password,
        );
      }
    });
  } finally {
    for (final client in clients) {
      await client.dispose();
    }
    File('.local/development-verification.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'verified_utc': DateTime.now().toUtc().toIso8601String(),
        'results': results,
      }),
    );
  }
}
