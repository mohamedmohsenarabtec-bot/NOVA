import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/strings.dart';
import '../../shared/app_controls.dart';
import '../../shared/brand.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';

class ConversationList extends StatefulWidget {
  final NovaRepository repo;
  const ConversationList({super.key, required this.repo});
  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  late Future<List<DbRow>> data = widget.repo.conversations();
  void reload() => setState(() => data = widget.repo.conversations());
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AsyncPane<List<DbRow>>(
      future: data,
      retry: reload,
      builder: (rows) => rows.isEmpty
          ? EmptyState(
              icon: Icons.forum_outlined,
              title: s.t('مساحة لأول مرحبًا', 'Room for a first hello'),
              body: s.t(
                'تظهر المحادثة عند الإعجاب المتبادل. سلامتك واختيارك أولًا.',
                'Conversations open after a mutual like. Your choice comes first.',
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                reload();
                await data;
              },
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.chat_bubble_outline),
                  ),
                  title: Text(s.t('محادثة متبادلة', 'Mutual connection')),
                  subtitle: Text(
                    rows[i]['created_at'].toString().substring(0, 10),
                  ),
                  trailing: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                  ),
                  onTap: () => context.go('/chat/${rows[i]['id']}'),
                ),
              ),
            ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final NovaRepository repo;
  final String conversationId;
  const ChatScreen({
    super.key,
    required this.repo,
    required this.conversationId,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final composer = TextEditingController();
  final rows = <DbRow>[];
  RealtimeChannel? channel;
  bool loading = true, failed = false, sending = false, more = true;
  @override
  void initState() {
    super.initState();
    load();
    unawaited(connect());
  }

  Future<void> connect() async {
    try {
      final connected = await widget.repo.watchMessages(
        widget.conversationId,
        () => load(),
      );
      if (mounted) {
        channel = connected;
      } else if (connected != null) {
        await widget.repo.client.removeChannel(connected);
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<void> load({bool older = false}) async {
    try {
      final result = await widget.repo.messages(
        widget.conversationId,
        before: older && rows.isNotEmpty
            ? DateTime.parse(rows.last['created_at'])
            : null,
      );
      if (!mounted) return;
      setState(() {
        if (!older) rows.clear();
        rows.addAll(result.where((r) => !rows.any((e) => e['id'] == r['id'])));
        more = result.length == 40;
        loading = false;
        failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    composer.dispose();
    if (channel != null) unawaited(widget.repo.client.removeChannel(channel!));
    super.dispose();
  }

  Future<void> send() async {
    final text = composer.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    await guarded(context, () async {
      await widget.repo.send(widget.conversationId, text);
      composer.clear();
      await load();
    });
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: s.t('رجوع', 'Back'),
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Row(
          children: [
            const NovaLogo(symbolOnly: true, size: 28),
            const SizedBox(width: 10),
            Flexible(child: Text(s.chats, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: const [AppControls()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              s.t(
                'محادثات خاصة بصلاحيات وصول. ليست مشفرة من طرف إلى طرف.',
                'Access-controlled private chats. Not end-to-end encrypted.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : failed
                ? Center(
                    child: TextButton(onPressed: load, child: Text(s.retry)),
                  )
                : rows.isEmpty
                ? EmptyState(
                    icon: Icons.auto_awesome,
                    title: s.t('شرارة البداية', 'First Spark'),
                    body: s.t(
                      'كيف يبدو يوم الإجازة المثالي بالنسبة لك؟',
                      'What does your perfect weekend look like?',
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length + (more ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == rows.length) {
                        return TextButton(
                          onPressed: () => load(older: true),
                          child: Text(s.t('رسائل أقدم', 'Older messages')),
                        );
                      }
                      final message = rows[i];
                      final mine = message['sender_id'] == widget.repo.uid;
                      return Align(
                        alignment: mine
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 520),
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: mine
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                message['body'],
                                style: TextStyle(
                                  color: mine
                                      ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                message['created_at'].toString().substring(
                                  11,
                                  16,
                                ),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (rows.isEmpty)
            TextButton(
              onPressed: () => composer.text = s.t(
                'أي شيء بسيط يحسن يومك فورًا؟',
                'What small thing instantly improves your day?',
              ),
              child: Text(s.t('استخدم شرارة البداية', 'Use First Spark')),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: composer,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: s.t('رسالتك', 'Your message'),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: s.t('إرسال', 'Send'),
                    onPressed: sending ? null : send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
