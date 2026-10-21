// Live owner-controlled smoke test. Uses only the public key for product flows.
// Generated passwords/tokens remain in memory and never enter logs or files.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:nova/core/config.dart';

class ApiFailure implements Exception {
  final int status;
  final String code;
  ApiFailure(this.status, this.code);
  @override
  String toString() => 'HTTP $status ($code)';
}

class Api {
  final String url, key;
  final client = HttpClient();
  Api(this.url, this.key);
  Future<({int status, dynamic data})> call(
    String method,
    String path, {
    String? token,
    Object? body,
    bool allowFailure = false,
  }) async {
    final request = await client
        .openUrl(method, Uri.parse('$url$path'))
        .timeout(const Duration(seconds: 25));
    request.headers.set('apikey', key);
    if (token != null) request.headers.set('Authorization', 'Bearer $token');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(const Duration(seconds: 25));
    final text = await utf8.decoder.bind(response).join();
    dynamic data;
    try {
      data = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      data = null;
    }
    if (response.statusCode >= 400 && !allowFailure) {
      throw ApiFailure(
        response.statusCode,
        data is Map
            ? (data['code'] ?? data['error_code'] ?? 'request_failed')
                  .toString()
            : 'request_failed',
      );
    }
    return (status: response.statusCode, data: data);
  }
}

class TestAccount {
  final String id, email, password;
  String token;
  TestAccount(this.id, this.email, this.password, this.token);
}

void require(bool value, String label) {
  if (!value) throw StateError(label);
}

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln(
      'Usage: dart run scripts/live_smoke.dart config/local.json OWNER_TEST_EMAIL_A OWNER_TEST_EMAIL_B [--verify-moderation]',
    );
    stderr.writeln(
      'Use two NEW email addresses you control. Accounts created by this run are deleted in finally; existing accounts are never modified.',
    );
    exitCode = 64;
    return;
  }
  final config = jsonDecode(
    File(args[0]).readAsStringSync().replaceFirst('\ufeff', ''),
  ) as Map<String, dynamic>;
  final url = config['SUPABASE_URL'] as String? ?? '';
  final key = config['SUPABASE_PUBLISHABLE_KEY'] as String? ?? '';
  require(ClientConfig.valid(url, key), 'Invalid public configuration');
  require(
    args[1] != args[2],
    'Two distinct owner-controlled addresses required',
  );
  final api = Api(url, key);
  final accounts = <TestAccount>[];
  final results = <Map<String, dynamic>>[];
  Future<void> check(String name, Future<void> Function() run) async {
    await run();
    results.add({'flow': name, 'status': 'PASS'});
    stdout.writeln('PASS: $name');
  }

  Future<dynamic> rpc(
    TestAccount account,
    String name, [
    Map<String, dynamic>? body,
  ]) async => (await api.call(
    'POST',
    '/rest/v1/rpc/$name',
    token: account.token,
    body: body ?? {},
  )).data;
  Future<List<dynamic>> rows(TestAccount account, String path) async =>
      List<dynamic>.from(
        (await api.call('GET', '/rest/v1/$path', token: account.token)).data
            as List,
      );
  Future<void> deny(
    TestAccount? account,
    String method,
    String path,
    Object body,
  ) async {
    final result = await api.call(
      method,
      path,
      token: account?.token,
      body: body,
      allowFailure: true,
    );
    require(result.status >= 400, 'Unauthorized mutation was accepted');
  }

  Future<TestAccount> signup(String email) async {
    final random = Random.secure();
    final password =
        'Nv!${base64Url.encode(List<int>.generate(30, (_) => random.nextInt(256)))}9a';
    final response = await api.call(
      'POST',
      '/auth/v1/signup',
      body: {
        'email': email,
        'password': password,
        'data': {'birth_date': '1995-01-01', 'consent_version': 'draft-v1'},
      },
    );
    final data = response.data as Map;
    require(
      data['access_token'] is String,
      'No immediate session; check Confirm email',
    );
    final account = TestAccount(
      (data['user'] as Map)['id'] as String,
      email,
      password,
      data['access_token'] as String,
    );
    accounts.add(account);
    return account;
  }

  Future<void> login(TestAccount account) async {
    final response = await api.call(
      'POST',
      '/auth/v1/token?grant_type=password',
      body: {'email': account.email, 'password': account.password},
    );
    account.token = (response.data as Map)['access_token'] as String;
  }

  Future<void> staffRole(TestAccount account, {required bool grant}) async {
    // Requires the owner's official CLI login. Only this run's newly-created test UUID is used.
    require(
      RegExp(r'^[0-9a-f-]{36}$').hasMatch(account.id),
      'Invalid test UUID',
    );
    final ref =
        config['SUPABASE_PROJECT_REF'] as String? ??
        Uri.parse(url).host.split('.').first;
    require(RegExp(r'^[a-z]{20}$').hasMatch(ref), 'Invalid project reference');
    final tool = Platform.isWindows
        ? '.tools/supabase/supabase.exe'
        : 'supabase';
    final sql = grant
        ? "insert into public.staff_roles(user_id,role) values('${account.id}','moderator') on conflict do nothing;"
        : "delete from public.staff_roles where user_id='${account.id}' and role='moderator';";
    final response = await Process.run(tool, [
      '--agent',
      'no',
      '--output-format',
      'text',
      'db',
      'query',
      '--project-ref',
      ref,
      sql,
    ]);
    require(
      response.exitCode == 0,
      'Official CLI could not change the temporary test role',
    );
  }

  TestAccount? moderator;
  String stage = 'preflight';
  try {
    await check(
      'existing Auth settings allow signup without email delivery',
      () async {
        final settings =
            (await api.call('GET', '/auth/v1/settings')).data as Map;
        require(
          settings['mailer_autoconfirm'] == true &&
              (settings['external'] as Map)['email'] == true &&
              settings['disable_signup'] != true,
          'Development email authentication not ready',
        );
        final probe = await api.call(
          'POST',
          '/rest/v1/rpc/client_readiness',
          body: {},
          allowFailure: true,
        );
        require(
          probe.status == 200 && probe.data == 4,
          'NOVA database migrations are not ready',
        );
      },
    );
    stage = 'signup';
    late TestAccount a, b;
    await check(
      'register two owner-controlled adults with immediate real sessions',
      () async {
        a = await signup(args[1]);
        b = await signup(args[2]);
      },
    );
    await check('logout and sign in again', () async {
      await api.call('POST', '/auth/v1/logout', token: a.token);
      await login(a);
    });
    await check(
      'duplicate account rejected',
      () => deny(null, 'POST', '/auth/v1/signup', {
        'email': a.email,
        'password': a.password,
        'data': {'birth_date': '1995-01-01', 'consent_version': 'draft-v1'},
      }),
    );
    await check(
      'invalid password rejected',
      () => deny(null, 'POST', '/auth/v1/token?grant_type=password', {
        'email': a.email,
        'password': 'deliberately-wrong-password',
      }),
    );
    stage = 'profiles';
    await check('load and save profiles, preferences and interests', () async {
      require(
        (await rows(a, 'profiles?select=id')).length == 1,
        'Own profile not available',
      );
      for (final account in [a, b]) {
        await rpc(account, 'save_profile', {
          'data': {
            'display_name': 'NOVA owner test',
            'gender': account == a ? 'woman' : 'man',
            'seeking_gender': account == a ? 'man' : 'woman',
            'intention': 'serious',
            'interests': ['books', 'music'],
            'min_age': 18,
            'max_age': 120,
            'onboarding_step': 5,
            'onboarding_complete': true,
          },
        });
        final profile =
            (await rows(
                  account,
                  'profiles?select=id,interests,min_age,max_age,onboarding_complete',
                )).single
                as Map;
        require(
          profile['onboarding_complete'] == true &&
              (profile['interests'] as List).contains('books') &&
              profile['max_age'] == 120,
          'Profile values not persisted',
        );
      }
    });
    await check('discovery returns compatible test profile', () async {
      bool found = false;
      for (var page = 0; page < 10; page++) {
        final profiles =
            await rpc(a, 'discover', {'page_offset': page * 20}) as List;
        if (profiles.any((p) => p['id'] == b.id)) {
          found = true;
          break;
        }
        if (profiles.length < 20) break;
      }
      require(found, 'Compatible test profile not found within 200 results');
    });
    await check(
      'RLS prevents other-profile reads and direct privileged writes',
      () async {
        require(
          (await rows(a, 'profiles?select=id&id=eq.${b.id}')).isEmpty,
          'Other private profile leaked',
        );
        await deny(a, 'PATCH', '/rest/v1/profiles?id=eq.${a.id}', {
          'verified': true,
        });
        await deny(a, 'POST', '/rest/v1/staff_roles', {
          'user_id': a.id,
          'role': 'administrator',
        });
        await deny(a, 'POST', '/rest/v1/entitlements', {
          'user_id': a.id,
          'feature': 'fake',
          'expires_at': '2099-01-01T00:00:00Z',
        });
        await deny(a, 'POST', '/rest/v1/rpc/apply_credit_delta', {
          'who': a.id,
          'delta': 100,
          'event_key': 'forged-test-credit',
          'reason': 'forged',
        });
      },
    );
    stage = 'matching';
    late String conversation;
    await check(
      'likes are deduplicated and reciprocal likes create one match',
      () async {
        require(
          await rpc(a, 'discovery_action', {
                'target_id': b.id,
                'action_kind': 'like',
              }) ==
              false,
          'One-sided like created match',
        );
        await rpc(a, 'discovery_action', {
          'target_id': b.id,
          'action_kind': 'like',
        });
        require(
          (await rows(
                a,
                'discovery_actions?select=target_id&target_id=eq.${b.id}',
              )).length ==
              1,
          'Duplicate action inserted',
        );
        require(
          await rpc(b, 'discovery_action', {
                'target_id': a.id,
                'action_kind': 'like',
              }) ==
              true,
          'Reciprocal match missing',
        );
        final conversations = await rows(a, 'conversations?select=id');
        require(conversations.length == 1, 'Canonical conversation missing');
        conversation = (conversations.single as Map)['id'] as String;
        require(
          (await rows(
                b,
                'conversations?select=id&id=eq.$conversation',
              )).length ==
              1,
          'Participant cannot access conversation',
        );
      },
    );
    stage = 'chat';
    await check(
      'both participants send and read persistent messages',
      () async {
        await rpc(a, 'send_message', {
          'conversation': conversation,
          'body': 'NOVA owner test A',
        });
        await rpc(b, 'send_message', {
          'conversation': conversation,
          'body': 'NOVA owner test B',
        });
        for (final account in [a, b]) {
          require(
            (await rows(
                  account,
                  'messages?select=id&conversation_id=eq.$conversation',
                )).length ==
                2,
            'Persistent messages missing',
          );
        }
        await deny(a, 'POST', '/rest/v1/messages', {
          'conversation_id': conversation,
          'sender_id': b.id,
          'body': 'forged sender',
        });
      },
    );
    await check(
      'fresh sign-in reloads messages from database (API, not browser UI)',
      () async {
        await login(a);
        require(
          (await rows(
                a,
                'messages?select=id&conversation_id=eq.$conversation',
              )).length ==
              2,
          'Messages lost across sessions',
        );
      },
    );
    stage = 'safety';
    await check(
      'report is stored and normal-user moderation is denied',
      () async {
        await api.call(
          'POST',
          '/rest/v1/reports',
          token: a.token,
          body: {'reporter_id': a.id, 'subject_id': b.id, 'category': 'safety'},
        );
        require(
          (await rows(a, 'reports?select=id&subject_id=eq.${b.id}')).length ==
              1,
          'Report missing',
        );
        await deny(a, 'POST', '/rest/v1/rpc/moderation_queue', {});
        await deny(b, 'POST', '/rest/v1/rpc/moderation_queue', {});
      },
    );
    if (args.contains('--verify-moderation')) {
      moderator = b;
      await check('authorized temporary moderator sees report without private chat bypass', () async {
        await staffRole(b, grant: true);
        final reports = await rpc(b, 'moderation_queue') as List;
        require(
          reports.any(
            (r) => r['reporter_id'] == a.id && r['subject_id'] == b.id,
          ),
          'Report absent from authorized queue',
        );
        await staffRole(b, grant: false);
        moderator = null;
      });
    } else {
      results.add({
        'flow': 'authorized moderation review',
        'status': 'NOT TESTED',
        'reason': 'Use --verify-moderation after official CLI authorization',
      });
    }
    await check(
      'block revokes both participants message reads and sends',
      () async {
        await api.call(
          'POST',
          '/rest/v1/blocks',
          token: a.token,
          body: {'actor_id': a.id, 'target_id': b.id},
        );
        for (final account in [a, b]) {
          require(
            (await rows(
              account,
              'messages?select=id&conversation_id=eq.$conversation',
            )).isEmpty,
            'Blocked conversation remains readable',
          );
          await deny(account, 'POST', '/rest/v1/rpc/send_message', {
            'conversation': conversation,
            'body': 'must be rejected',
          });
        }
      },
    );
  } catch (error) {
    exitCode = 1;
    final safeError = error is ApiFailure
        ? error.toString()
        : error is StateError
        ? error.message
        : 'Connection or execution error';
    results.add({'flow': stage, 'status': 'FAIL', 'reason': safeError});
    stderr.writeln('FAIL: $stage — $safeError');
  } finally {
    if (moderator != null) {
      try {
        await staffRole(moderator!, grant: false);
      } catch (_) {
        results.add({
          'flow': 'temporary test role cleanup',
          'status': 'INCOMPLETE',
        });
        exitCode = 1;
      }
    }
    for (final account in accounts.reversed) {
      try {
        await rpc(account, 'delete_my_account');
        results.add({
          'flow': 'delete only account created by this test run',
          'status': 'PASS',
        });
      } catch (_) {
        results.add({
          'flow': 'test account cleanup',
          'status': 'INCOMPLETE',
          'user_id': account.id,
        });
        exitCode = 1;
      }
    }
    results.add({
      'flow':
          'browser reload, local-storage session restore and Realtime delivery',
      'status': 'NOT TESTED',
      'reason': 'API tests do not replace a real browser/device test',
    });
    Directory('.local').createSync(recursive: true);
    File('.local/live-results.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'completed_utc': DateTime.now().toUtc().toIso8601String(),
        'results': results,
      }),
    );
    api.client.close(force: true);
  }
}
