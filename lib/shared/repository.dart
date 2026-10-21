import 'package:supabase_flutter/supabase_flutter.dart';

typedef DbRow = Map<String, dynamic>;

class NovaRepository {
  final SupabaseClient client;
  NovaRepository(this.client);
  String get uid => client.auth.currentUser!.id;
  Future<DbRow?> profile() =>
      client.from('profiles').select().eq('id', uid).maybeSingle();
  Future<List<DbRow>> discover({int page = 0}) async => List<DbRow>.from(
    await client.rpc('discover', params: {'page_offset': page * 20}),
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
  RealtimeChannel? watchMessages(String id, void Function() changed) => client
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
      .subscribe();
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
  Future<List<DbRow>> conversations() => client
      .from('conversations')
      .select()
      .order('created_at', ascending: false)
      .limit(50);
  Future<List<DbRow>> messages(String id, {DateTime? before}) async {
    var query = client.from('messages').select().eq('conversation_id', id);
    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }
    return query.order('created_at', ascending: false).limit(40);
  }

  Future<void> send(String id, String body) =>
      client.rpc('send_message', params: {'conversation': id, 'body': body});
  Future<List<DbRow>> plans() =>
      client.from('products').select().eq('active', true).order('sort_order');
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
}
