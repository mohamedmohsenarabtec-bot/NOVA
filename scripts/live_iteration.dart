// Real development acceptance. Newly-created identities are isolated from
// ordinary discovery before onboarding. Passwords/tokens stay in memory.
// --retain-fictional creates an explicitly labeled development seed and writes
// its generated credentials ONLY under ignored .local for controlled testing.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:supabase/supabase.dart';
import 'package:nova/core/config.dart';
import 'package:nova/core/photo_processing.dart';
import 'package:nova/shared/repository.dart';

import 'live_smoke.dart' show Api, TestAccount, require;
import 'browser_probe.dart';

Future<void> main(List<String> args) async {
  final config = jsonDecode(
    File(args.isEmpty ? 'config/local.json' : args.first)
        .readAsStringSync()
        .replaceFirst('\ufeff', ''),
  ) as Map;
  require(
    ClientConfig.valid(
      config['SUPABASE_URL'],
      config['SUPABASE_PUBLISHABLE_KEY'],
    ),
    'Invalid public configuration',
  );
  final api = Api(config['SUPABASE_URL'], config['SUPABASE_PUBLISHABLE_KEY']);
  final run = DateTime.now().microsecondsSinceEpoch.toString();
  final accounts = <TestAccount>[],
      photos = <({TestAccount owner, Map photo})>[];
  final results = <Map<String, dynamic>>[];
  final retain = args.contains('--retain-fictional');
  var retainedSuccessfully = false;
  Future<void> check(String name, Future<void> Function() action) async {
    await action();
    results.add({'flow': name, 'status': 'PASS'});
    stdout.writeln('PASS: $name');
  }

  Future<dynamic> rpc(
    TestAccount a,
    String name, [
    Map<String, dynamic> body = const {},
  ]) async => (await api.call(
    'POST',
    '/rest/v1/rpc/$name',
    token: a.token,
    body: body,
  )).data;
  Future<List<dynamic>> rows(TestAccount a, String table) async =>
      List<dynamic>.from(
        (await api.call('GET', '/rest/v1/$table', token: a.token)).data as List,
      );
  Future<void> denied(
    TestAccount a,
    String method,
    String path,
    Map body,
  ) async {
    final r = await api.call(
      method,
      path,
      token: a.token,
      body: body,
      allowFailure: true,
    );
    require(r.status >= 400, 'Unauthorized operation accepted');
  }

  Future<void> upload(TestAccount a, String path, Uint8List bytes) async {
    final request = await api.client.postUrl(
      Uri.parse('${api.url}/storage/v1/object/private-media/$path'),
    );
    request.headers.set('apikey', api.key);
    request.headers.set('Authorization', 'Bearer ${a.token}');
    request.headers.set('Content-Type', 'image/jpeg');
    request.add(bytes);
    final response = await request.close();
    await response.drain<void>();
    require(response.statusCode < 300, 'Storage upload failed');
  }

  Future<int> download(TestAccount a, String path) async {
    final request = await api.client.postUrl(
      Uri.parse('${api.url}/functions/v1/profile-photo'),
    );
    request.headers.set('apikey', api.key);
    request.headers.set('Authorization', 'Bearer ${a.token}');
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({'photo_id': path.split('/').last.replaceFirst('.jpg', '')}),
    );
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  }

  Future<void> removePhoto(TestAccount a, Map photo) async {
    await api.call(
      'DELETE',
      '/storage/v1/object/private-media',
      token: a.token,
      body: {
        'prefixes': [photo['path']],
      },
    );
    await rpc(a, 'manage_profile_photos', {
      'photo_id': photo['id'],
      'remove_photo': true,
    });
  }

  try {
    await check(
      'existing backend capabilities and immediate signup settings',
      () async {
        final settings =
            (await api.call('GET', '/auth/v1/settings')).data as Map;
        require(
          settings['mailer_autoconfirm'] == true &&
              settings['disable_signup'] != true,
          'Signup would require email; abort',
        );
        require(
          (await api.call(
                'POST',
                '/rest/v1/rpc/client_capabilities',
                body: {},
              )).data ==
              10,
          'Migrations missing',
        );
      },
    );
    for (var i = 0; i < 2; i++) {
      final password =
          'Nv!${base64UrlEncode(List.generate(30, (_) => Random.secure().nextInt(256)))}9a';
      final email = 'nova.qa.$run.$i@example.com';
      final response =
          (await api.call(
                'POST',
                '/auth/v1/signup',
                body: {
                  'email': email,
                  'password': password,
                  'data': {
                    'birth_date': '1995-01-01',
                    'consent_version': 'draft-v1',
                    'qa_run': run,
                  },
                },
              )).data
              as Map;
      require(
        response['access_token'] is String,
        'No immediate signup session',
      );
      accounts.add(
        TestAccount(
          response['user']['id'],
          email,
          password,
          response['access_token'],
          response['refresh_token'],
        ),
      );
    }
    final ids = accounts.map((a) => a.id).toList();
    require(
      ids.every((id) => RegExp(r'^[a-f0-9-]{36}$').hasMatch(id)),
      'Invalid UUID',
    );
    final flagFile = File('.local/qa-isolation.sql')
      ..parent.createSync(recursive: true);
    flagFile.writeAsStringSync(
      "update public.profiles p set is_test_account=true from auth.users u where p.id=u.id and p.id in (${ids.map((id) => "'$id'::uuid").join(',')}) and u.raw_user_meta_data->>'qa_run'='$run' and p.created_at>now()-interval '10 minutes';",
    );
    final cli = await Process.run(
      File('.tools/supabase/supabase.exe').absolute.path,
      [
        '--agent',
        'no',
        '--output-format',
        'text',
        'db',
        'query',
        '--linked',
        '--file',
        flagFile.path,
      ],
    );
    require(
      cli.exitCode == 0,
      'Authorized CLI required to isolate development identities',
    );
    final a = accounts[0], b = accounts[1];
    await check('fictional seed isolated before becoming discoverable; distinct profiles persist', () async {
      for (var i = 0; i < accounts.length; i++) {
        final account = accounts[i];
        require(
          (await rows(
                account,
                'profiles?select=is_test_account',
              )).single['is_test_account'] ==
              true,
          'Development isolation flag missing',
        );
        await rpc(account, 'save_profile', {
          'data': {
            'display_name': 'Fictional QA ${i + 1}',
            'gender': i == 0 ? 'man' : 'woman',
            'seeking_gender': i == 0 ? 'woman' : 'man',
            'intention': 'serious',
            'bio': 'Private QA biography',
            'city': 'QA region',
            'languages': ['Arabic', 'English'],
            'interests': ['books'],
            'details': {'occupation': 'Private QA occupation'},
            'public_fields': ['city', 'languages', 'interests', 'intention'],
            'onboarding_complete': true,
            'onboarding_step': 5,
          },
        });
      }
      require(
        (await rpc(a, 'discover_profiles', {'page_offset': 0}) as List).any(
          (p) => p['id'] == b.id,
        ),
        'Compatible test profile missing',
      );
    });
    await check('public projection and private profile RLS prevent contact and hidden-field leakage', () async {
      require(
        (await rows(a, 'profiles?select=id&id=eq.${b.id}')).isEmpty,
        'Other private profile exposed',
      );
      final p = await rpc(a, 'public_profile', {'target': b.id}) as Map;
      require(
        !p.containsKey('email') &&
            !p.containsKey('birth_date') &&
            !p.containsKey('bio') &&
            (p['details'] as Map).isEmpty,
        'Hidden field leaked',
      );
      await denied(a, 'POST', '/rest/v1/staff_roles', {
        'user_id': a.id,
        'role': 'administrator',
      });
    });
    await check(
      'saved regional filtering and server-side advanced-filter gate',
      () async {
        await rpc(a, 'save_discovery_filters', {
          'data': {'city': 'not-a-real-test-region'},
        });
        require(
          (await rpc(a, 'discover_profiles') as List).isEmpty,
          'Regional filter ignored',
        );
        await denied(a, 'POST', '/rest/v1/rpc/save_discovery_filters', {
          'data': {'has_photo': true},
        });
        await rpc(a, 'save_discovery_filters', {'data': {}});
      },
    );
    await check(
      'favorites are private and deduplicated without notifications',
      () async {
        await rpc(a, 'toggle_favorite', {'target': b.id, 'enabled': true});
        await rpc(a, 'toggle_favorite', {'target': b.id, 'enabled': true});
        require(
          (await rows(a, 'favorites?select=target_id')).length == 1,
          'Duplicate favorite',
        );
        require(
          (await rows(
            b,
            'favorites?select=target_id&user_id=eq.${a.id}',
          )).isEmpty,
          'Favorite leaked',
        );
        require(
          (await rpc(b, 'notification_inbox'))['unread'] == 0,
          'Favorite sent notification',
        );
      },
    );
    await check(
      'real JPEG upload, finalization, private access and photo ordering',
      () async {
        final pixels = image.Image(width: 64, height: 64);
        image.fill(pixels, color: image.ColorRgb8(100, 80, 170));
        final bytes = processProfilePhoto(
          Uint8List.fromList(image.encodePng(pixels)),
        );
        for (var i = 0; i < 2; i++) {
          final photo = Map<String, dynamic>.from(
            await rpc(a, 'prepare_profile_photo', {
              'photo_visibility': 'private',
            }),
          );
          photos.add((owner: a, photo: photo));
          await upload(a, photo['path'], bytes);
          await rpc(a, 'finalize_profile_photo', {'photo_id': photo['id']});
        }
        require(
          await download(b, photos.first.photo['path']) >= 400,
          'Private photo bytes leaked',
        );
        await rpc(a, 'manage_profile_photos', {
          'ordered_ids': photos.reversed.map((p) => p.photo['id']).toList(),
        });
        final ordered = await rows(
          a,
          'profile_photos?select=id&order=position.asc',
        );
        require(
          ordered.first['id'] == photos.last.photo['id'],
          'Photo order not saved',
        );
        await rpc(a, 'manage_profile_photos', {
          'photo_id': photos.first.photo['id'],
          'photo_visibility': 'public',
        });
        require(
          await download(b, photos.first.photo['path']) == 200,
          'Permitted photo cannot be downloaded',
        );
        final projected =
            await rpc(b, 'public_profile', {'target': a.id}) as Map;
        require(
          (projected['photos'] as List).length == 1,
          'Restricted photo metadata leaked',
        );
      },
    );
    late String conversation;
    await check('pending likes have real expiration; reciprocal likes create one persistent match', () async {
      require(
        await rpc(a, 'discovery_action', {
              'target_id': b.id,
              'action_kind': 'like',
            }) ==
            false,
        'One-sided match',
      );
      final incoming = await rpc(b, 'interaction_overview') as Map;
      require(
        incoming['incoming_count'] == 1 &&
            (incoming['incoming'] as List).isEmpty,
        'Free liker identity leaked',
      );
      require(
        await rpc(b, 'discovery_action', {
              'target_id': a.id,
              'action_kind': 'like',
            }) ==
            true,
        'Mutual match missing',
      );
      final chats = await rpc(a, 'chat_list') as List;
      require(chats.length == 1, 'Duplicate or missing chat');
      conversation = chats.single['id'];
    });
    await check(
      'two-way persistent chat and authenticated realtime delivery',
      () async {
        await rpc(a, 'send_message', {
          'conversation': conversation,
          'body': 'Fictional QA greeting',
        });
        final live = SupabaseClient(
          api.url,
          api.key,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        try {
          await live.auth.signInWithPassword(
            email: a.email,
            password: a.password,
          );
          final repository = NovaRepository(live);
          final orderedPhotos = await repository.photos();
          require(
            orderedPhotos.first['position'] == 0,
            'Photo order not ascending',
          );
          require(
            (await repository.offers()).first['tier'] == 'free',
            'Free catalog should precede paid proposals',
          );
          await live.realtime.setAuth(live.auth.currentSession!.accessToken);
          final ready = Completer<void>(), delivered = Completer<void>();
          final body = 'Fictional QA realtime $run';
          final channel = live
              .channel('qa:$run')
              .onSystemEvents((e) {
                if (e is Map &&
                    e['extension'] == 'postgres_changes' &&
                    e['status'] == 'ok' &&
                    !ready.isCompleted) {
                  ready.complete();
                }
              })
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
              .subscribe();
          await ready.future.timeout(const Duration(seconds: 30));
          await rpc(b, 'send_message', {
            'conversation': conversation,
            'body': body,
          });
          await delivered.future.timeout(const Duration(seconds: 30));
          await live.removeChannel(channel);
          require(
            (await rows(
                  a,
                  'messages?select=id&conversation_id=eq.$conversation',
                )).length ==
                2,
            'Chat not persisted',
          );
        } finally {
          await live.dispose();
        }
      },
    );
    await check('notification unread/read state, billing preview and referral abuse controls', () async {
      require(
        (await rpc(a, 'notification_inbox'))['unread'] > 0,
        'Real notifications missing',
      );
      await rpc(a, 'read_notifications');
      require(
        (await rpc(a, 'notification_inbox'))['unread'] == 0,
        'Read state missing',
      );
      require(
        (await rows(a, 'notifications?select=id&user_id=eq.${b.id}')).isEmpty,
        'Other notification leaked',
      );
      require(
        (await rpc(a, 'membership_status'))['purchases_enabled'] == false,
        'Live payments unexpectedly enabled',
      );
      final referral = await rpc(a, 'referral_progress') as Map;
      await denied(a, 'POST', '/rest/v1/rpc/claim_referral', {
        'invitation_code': referral['code'],
      });
      await rpc(b, 'claim_referral', {'invitation_code': referral['code']});
      await denied(b, 'POST', '/rest/v1/rpc/claim_referral', {
        'invitation_code': referral['code'],
      });
      require(
        (await rpc(a, 'referral_progress'))['pending'] == 1,
        'Referral not recorded',
      );
      await denied(a, 'POST', '/rest/v1/rpc/grant_referral_reward', {
        'referral_id': '00000000-0000-0000-0000-000000000000',
      });
    });
    final browserArgument = args.where((v) => v.startsWith('--browser-url='));
    if (browserArgument.isNotEmpty) {
      await rpc(a, 'send_message', {
        'conversation': conversation,
        'body': 'Fictional QA browser check',
      });
      await check('published UI, localization, themes, account screens and persistent chat', () async {
        await BrowserProbe.verify(
          url: browserArgument.single.substring('--browser-url='.length),
          email: a.email,
          password: a.password,
          conversationId: conversation,
          expectedMessage: 'Fictional QA greeting',
          expanded: true,
        );
      });
    }
    if (!retain) {
      await check(
        'block immediately denies chat and authenticated photo retrieval',
        () async {
          await api.call(
            'POST',
            '/rest/v1/blocks',
            token: b.token,
            body: {'actor_id': b.id, 'target_id': a.id},
          );
          require(
            (await rows(
              a,
              'messages?select=id&conversation_id=eq.$conversation',
            )).isEmpty,
            'Block did not deny chat',
          );
          require(
            await download(b, photos.first.photo['path']) >= 400,
            'Block did not revoke photo access',
          );
        },
      );
    }
    if (retain) {
      File('.local/fictional-test-access.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'created_utc': DateTime.now().toUtc().toIso8601String(),
          'fictional_only': true,
          'accounts': accounts
              .map(
                (a) => {'email': a.email, 'password': a.password, 'id': a.id},
              )
              .toList(),
        }),
      );
      stdout.writeln(
        'Fictional development seed retained; generated access is in ignored .local/fictional-test-access.json only.',
      );
      retainedSuccessfully = true;
    }
  } catch (error) {
    exitCode = 1;
    final reason = error is StateError
        ? error.message.toString()
        : error.runtimeType.toString();
    results.add({
      'flow': 'live acceptance',
      'status': 'INCOMPLETE',
      'reason': reason,
    });
    stderr.writeln('INCOMPLETE: live acceptance ($reason)');
  } finally {
    if (!retainedSuccessfully) {
      for (final p in photos.reversed) {
        try {
          await removePhoto(p.owner, p.photo);
        } catch (_) {
          exitCode = 1;
          results.add({'flow': 'test photo cleanup', 'status': 'INCOMPLETE'});
        }
      }
      for (final a in accounts.reversed) {
        try {
          await rpc(a, 'delete_my_account');
          results.add({
            'flow': 'delete only newly-created QA identity',
            'status': 'PASS',
          });
        } catch (_) {
          exitCode = 1;
          results.add({
            'flow': 'new QA account cleanup',
            'status': 'INCOMPLETE',
          });
        }
      }
    }
    File('.local/iteration-live.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'verified_utc': DateTime.now().toUtc().toIso8601String(),
        'results': results,
      }),
    );
    api.client.close(force: true);
  }
}
