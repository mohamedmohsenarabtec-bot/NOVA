import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';
import '../profiles/profile_card.dart';

class ConnectionsScreen extends StatefulWidget {
  final NovaRepository repo;
  final bool favorites;
  const ConnectionsScreen({
    super.key,
    required this.repo,
    this.favorites = false,
  });
  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  late Future<dynamic> data = load();
  Timer? ticker;
  Future<dynamic> load() =>
      widget.favorites ? widget.repo.favorites() : widget.repo.interactions();
  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          data = load();
        });
      }
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  void reload() => setState(() {
    data = load();
  });
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AsyncPane<dynamic>(
      future: data,
      retry: reload,
      builder: (value) {
        final overview = widget.favorites
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(value as Map);
        final entries = widget.favorites
            ? List<dynamic>.from(value as List)
            : List<dynamic>.from(overview['incoming'] ?? []);
        Widget card(dynamic p, {bool actions = true}) => ProfileCard(
          repo: widget.repo,
          profile: Map<String, dynamic>.from(p),
          actions: actions,
          onAction: reload,
          onFavoriteChanged: widget.favorites ? reload : null,
        );
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.favorites
                  ? s.t('مفضلتي الخاصة', 'My private favorites')
                  : s.t('من أعجبوا بي', 'Liked you'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            if (widget.favorites)
              Text(
                s.t(
                  'محفوظة لك وحدك. لا يُرسل إشعار عند الحفظ.',
                  'Only you can see bookmarks. Saving sends no notification.',
                ),
              ),
            if (!widget.favorites) ...[
              Text(
                s.t(
                  'إعجابات مؤهلة معلقة: ${overview['incoming_count']}',
                  'Eligible pending likes: ${overview['incoming_count']}',
                ),
              ),
              if (overview['can_view_likers'] != true)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.t(
                        'تظل هوية المعجبين خاصة. استحقاق Premium صالح يتيح عرض الملفات المسموح بها فقط؛ الشراء غير مفعل. يظل التطابق والدردشة مجانيين.',
                        'Liker identities remain private. A valid Premium entitlement reveals only permitted profiles; purchases are disabled. Mutual matching and chat remain free.',
                      ),
                    ),
                  ),
                ),
            ],
            for (final e in entries) ...[
              if (!widget.favorites)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ExpirationLabel(expiresAt: e['expires_at']),
                ),
              card(
                widget.favorites ? e : e['profile'],
                actions: !widget.favorites,
              ),
            ],
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.favorites
                      ? s.t('لم تحفظ ملفات بعد.', 'No saved profiles yet.')
                      : s.t(
                          'لا توجد ملفات متاحة للعرض الآن.',
                          'No profiles available to display right now.',
                        ),
                ),
              ),
            if (!widget.favorites) ...[
              const Divider(height: 32),
              Text(
                s.t('إعجاباتي المرسلة', 'My pending likes'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final e in overview['outgoing'] as List? ?? []) ...[
                ExpirationLabel(expiresAt: e['expires_at']),
                card(e['profile'], actions: false),
              ],
            ],
          ],
        );
      },
    );
  }
}

class ExpirationLabel extends StatelessWidget {
  final String expiresAt;
  const ExpirationLabel({super.key, required this.expiresAt});
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final remaining = DateTime.parse(expiresAt)
        .toUtc()
        .difference(DateTime.now().toUtc());
    return Text(
      remaining.isNegative
          ? s.t('انتهت المهلة', 'Expired')
          : s.t(
              'المتبقي: ${remaining.inHours} ساعة و${remaining.inMinutes % 60} دقيقة',
              'Remaining: ${remaining.inHours}h ${remaining.inMinutes % 60}m',
            ),
    );
  }
}
