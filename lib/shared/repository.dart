import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:typed_data';

import '../features/auth/auth_feedback.dart';

typedef DbRow = Map<String, dynamic>;

class NovaRepository {
  final SupabaseClient client;
  NovaRepository(this.client);
  String get uid => client.auth.currentUser!.id;
  Future<SignupResult> register({
    required String email,
    required String password,
    required DateTime birth,
  }) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'birth_date': birth.toIso8601String().substring(0, 10),
        'consent_version': 'draft-v1',
      },
    );
    if (response.session != null) return SignupResult.signedIn;
    if (response.user?.identities?.isEmpty == true) {
      return SignupResult.alreadyRegistered;
    }
    return SignupResult.confirmationRequired;
  }

  Future<DbRow?> profile() =>
      client.from('profiles').select().eq('id', uid).maybeSingle();
  Future<List<DbRow>> discover({int page = 0}) async => List<DbRow>.from(
    await client.rpc('discover_profiles', params: {'page_offset': page * 20}),
  );
  Future<void> saveProfile(DbRow values) async =>
      client.rpc('save_profile', params: {'data': values});
  Future<bool> act(String target, String kind) async =>
      (await client.rpc(
        'discovery_action',
        params: {'target_id': target, 'action_kind': kind},
      )) ==
      true;
  Future<void> block(String target) async => client
      .from('blocks')
      .upsert(
        {'actor_id': uid, 'target_id': target},
        onConflict: 'actor_id,target_id',
        ignoreDuplicates: true,
      );
  Future<RealtimeChannel?> watchMessages(
    String id,
    void Function() changed,
  ) async {
    final token = client.auth.currentSession?.accessToken;
    if (token == null) throw StateError('Session expired');
    await client.realtime.setAuth(token);
    return client
        .channel('chat:$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: id,
          ),
          callback: (_) => changed(),
        )
        .onSystemEvents((event) {
          // SUBSCRIBED can precede the replication listener. Re-fetch after
          // actual readiness (also on reconnect) to close that delivery gap.
          if (event is Map &&
              event['extension'] == 'postgres_changes' &&
              event['status'] == 'ok') {
            changed();
          }
        })
        .subscribe();
  }

  Future<List<DbRow>> blocks() =>
      client.from('blocks').select('target_id').eq('actor_id', uid);
  Future<void> unblock(String target) => client
      .from('blocks')
      .delete()
      .eq('actor_id', uid)
      .eq('target_id', target);
  Future<void> report(String target, String category) => client
      .from('reports')
      .insert({'reporter_id': uid, 'subject_id': target, 'category': category});
  Future<List<DbRow>> conversations() async =>
      List<DbRow>.from(await client.rpc('chat_list'));
  Future<List<DbRow>> messages(String id, {DateTime? before}) async {
    var query = client.from('messages').select().eq('conversation_id', id);
    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }
    return query.order('created_at', ascending: false).limit(40);
  }

  Future<void> send(String id, String body) =>
      client.rpc('send_message', params: {'conversation': id, 'body': body});
  Future<List<DbRow>> plans() => offers();
  Future<List<DbRow>> entitlements() => client
      .from('entitlements')
      .select()
      .eq('user_id', uid)
      .gt('expires_at', DateTime.now().toUtc().toIso8601String());
  Future<List<DbRow>> roles() =>
      client.from('staff_roles').select('role').eq('user_id', uid);
  Future<List<DbRow>> queue() async =>
      List<DbRow>.from(await client.rpc('moderation_queue'));
  Future<void> moderate(String reportId, String decision) => client.rpc(
    'moderate_report',
    params: {'report_id': reportId, 'decision': decision},
  );
  Future<void> ticket(String body) =>
      client.from('support_tickets').insert({'user_id': uid, 'body': body});
  Future<void> deleteAccount() => client.rpc('delete_my_account');
  Future<dynamic> exportData() => client.rpc('export_my_data');

  Future<DbRow> publicProfile(String id) async => Map<String, dynamic>.from(
    await client.rpc('public_profile', params: {'target': id}),
  );
  Future<DbRow> discoverySummary() async =>
      Map<String, dynamic>.from(await client.rpc('discovery_summary'));
  Future<void> saveFilters(DbRow filters) =>
      client.rpc('save_discovery_filters', params: {'data': filters});
  Future<void> favorite(String id, bool enabled) =>
      client.rpc('toggle_favorite', params: {'target': id, 'enabled': enabled});
  Future<List<DbRow>> favorites() async =>
      List<DbRow>.from(await client.rpc('favorite_profiles'));
  Future<DbRow> interactions() async =>
      Map<String, dynamic>.from(await client.rpc('interaction_overview'));
  Future<DbRow> notifications({int offset = 0}) async =>
      Map<String, dynamic>.from(
        await client.rpc('notification_inbox', params: {'page_offset': offset}),
      );
  Future<void> readNotifications([String? id]) =>
      client.rpc('read_notifications', params: {'notification_id': id});
  Future<DbRow> membership() async =>
      Map<String, dynamic>.from(await client.rpc('membership_status'));
  Future<List<DbRow>> offers() =>
      client.from('membership_offers').select().order('price_minor');
  Future<DbRow> referrals() async =>
      Map<String, dynamic>.from(await client.rpc('referral_progress'));
  Future<void> claimReferral(String code) =>
      client.rpc('claim_referral', params: {'invitation_code': code});
  Future<List<DbRow>> photos() => client
      .from('profile_photos')
      .select()
      .eq('owner_id', uid)
      .order('position');
  Future<Uint8List> downloadPhoto(String path) async {
    final id = path.split('/').last.replaceFirst('.jpg', '');
    final response = await client.functions.invoke(
      'profile-photo',
      body: {'photo_id': id},
    );
    return response.data as Uint8List;
  }

  Future<void> photoOrder(List<String> ids) =>
      client.rpc('manage_profile_photos', params: {'ordered_ids': ids});
  Future<void> photoPrivacy(String id, String visibility) => client.rpc(
    'manage_profile_photos',
    params: {'photo_id': id, 'photo_visibility': visibility},
  );
  Future<void> removePhoto(DbRow photo) async {
    await client.storage.from('private-media').remove([
      photo['path'] as String,
    ]);
    await client.rpc(
      'manage_profile_photos',
      params: {'photo_id': photo['id'], 'remove_photo': true},
    );
  }

  Future<void> endMatch(String id) =>
      client.rpc('end_match', params: {'conversation': id});
  Future<void> markChatRead(String id) =>
      client.rpc('mark_chat_read', params: {'conversation': id});
  Future<void> requestDeletion({bool cancel = false}) => client.rpc(
    'request_account_deletion',
    params: {'cancel_request': cancel},
  );
}
