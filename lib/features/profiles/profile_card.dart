import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';
import 'profile_photo.dart';
import 'profile_detail.dart';

class ProfileCard extends StatefulWidget {
  final NovaRepository repo;
  final DbRow profile;
  final VoidCallback? onAction;
  final VoidCallback? onFavoriteChanged;
  final bool actions;
  const ProfileCard({
    super.key,
    required this.repo,
    required this.profile,
    this.onAction,
    this.onFavoriteChanged,
    this.actions = true,
  });
  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  late bool favorite = widget.profile['is_favorite'] == true;
  bool busy = false;
  Future<void> saveFavorite() async {
    final desired = !favorite;
    setState(() => busy = true);
    await guarded(context, () async {
      await widget.repo.favorite(widget.profile['id'], desired);
      if (mounted) setState(() => favorite = desired);
      widget.onFavoriteChanged?.call();
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> act(String kind) async {
    setState(() => busy = true);
    await guarded(context, () async {
      final matched = await widget.repo.act(widget.profile['id'], kind);
      if (mounted && matched) {
        final s = Strings.of(context);
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.favorite),
            title: Text(s.t('شرارة متبادلة!', 'A mutual spark!')),
            content: Text(
              s.t(
                'يمكنكما بدء الدردشة من المحادثات.',
                'You can now chat in Conversations.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(s.t('رائع', 'Continue')),
              ),
            ],
          ),
        );
      }
      widget.onAction?.call();
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context), p = widget.profile;
    final photos = p['photos'] as List? ?? [];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => showProfileDetail(context, p, repo: widget.repo),
              child: ProfilePhoto(
                repo: widget.repo,
                path: photos.isEmpty ? null : photos.first['path'],
                height: 200,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        showProfileDetail(context, p, repo: widget.repo),
                    child: Text(
                      '${p['display_name']}، ${p['age']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: s.t(
                    favorite ? 'إزالة من المفضلة' : 'حفظ في المفضلة',
                    favorite ? 'Remove favorite' : 'Save favorite',
                  ),
                  onPressed: busy ? null : saveFavorite,
                  icon: Icon(
                    favorite ? Icons.bookmark : Icons.bookmark_outline,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: s.t('السلامة', 'Safety'),
                  onSelected: (v) => guarded(context, () async {
                    if (v == 'block') {
                      await widget.repo.block(p['id']);
                    } else {
                      await widget.repo.report(p['id'], 'safety');
                    }
                    widget.onAction?.call();
                  }),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'block',
                      child: Text(s.t('حظر', 'Block')),
                    ),
                    PopupMenuItem(
                      value: 'report',
                      child: Text(s.t('إبلاغ', 'Report')),
                    ),
                  ],
                ),
              ],
            ),
            if ((p['city'] ?? '') != '') Text(p['city']),
            if (p['is_test_account'] == true)
              Text(
                s.t('حساب تطوير خيالي', 'Fictional development account'),
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            if (p['verified'] == true)
              Text(s.t('توثيق تمت مراجعته', 'Verification reviewed')),
            if (p['is_match'] == true)
              Text(s.t('تطابق متبادل', 'Mutual match')),
            if (p['shared_interests'] != null)
              Text(
                s.t(
                  'اهتمامات مشتركة: ${p['shared_interests']}',
                  'Shared interests: ${p['shared_interests']}',
                ),
              ),
            Text(
              (p['interests'] as List? ?? []).take(4).join(' • '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.actions) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => act('pass'),
                      child: Text(s.t('تخطّي', 'Pass')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : () => act('like'),
                      icon: const Icon(Icons.favorite_outline),
                      label: Text(s.t('إعجاب', 'Like')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
