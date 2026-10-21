import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';
import '../profiles/profile_detail.dart';

class DiscoverScreen extends StatefulWidget {
  final NovaRepository repo;
  const DiscoverScreen({super.key, required this.repo});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late Future<List<DbRow>> data = widget.repo.discover();
  int page = 0;
  bool compact = false, busy = false;
  final removed = <String>{};
  void reload() => setState(() {
    removed.clear();
    data = widget.repo.discover(page: page);
  });
  Future<void> action(DbRow p, String kind) async {
    setState(() => busy = true);
    await guarded(context, () async {
      final matched = await widget.repo.act(p['id'], kind);
      if (!mounted) return;
      setState(() => removed.add(p['id']));
      if (matched) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.favorite,
              color: Color(0xFFFF9B91),
              size: 56,
            ),
            title: Text(
              Strings.of(context).t('شرارة متبادلة!', 'A mutual spark!'),
            ),
            content: Text(
              Strings.of(context).t(
                'يمكنكما الآن بدء محادثة من تبويب المحادثات.',
                'You can now say hello from Conversations.',
              ),
            ),
          ),
        );
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('تواصل يبدأ بنية', 'People, with intention'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.t(
                        'اهتمامات مشتركة. فرص لحكايات حقيقية.',
                        'Shared interests. Space for something real.',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: s.t('تغيير العرض', 'Change layout'),
                onPressed: () => setState(() => compact = !compact),
                icon: Icon(compact ? Icons.grid_view : Icons.view_list),
              ),
              IconButton(
                tooltip: s.retry,
                onPressed: reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncPane<List<DbRow>>(
            future: data,
            retry: reload,
            builder: (rows) {
              final profiles = rows
                  .where((p) => !removed.contains(p['id']))
                  .toList();
              if (profiles.isEmpty) {
                return EmptyState(
                  icon: Icons.nights_stay_outlined,
                  title: s.t('كل لقاء في وقته', 'Good connections take time'),
                  body: s.t(
                    'لا توجد ملفات مناسبة في هذه الصفحة حاليًا. جرّب الصفحة التالية أو عد لاحقًا.',
                    'No eligible profiles on this page. Try the next page or return later.',
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, size) => GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: compact
                        ? 1
                        : (size.maxWidth / 340).floor().clamp(1, 4),
                    mainAxisExtent: compact ? 190 : 360,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: profiles.length,
                  itemBuilder: (context, i) {
                    final p = profiles[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!compact)
                              Expanded(
                                child: Center(
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                    child: Text(
                                      (p['display_name'] as String)
                                          .characters
                                          .first,
                                      style: const TextStyle(fontSize: 40),
                                    ),
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => showProfileDetail(context, p),
                                    child: Text(
                                      '${p['display_name']}، ${p['age']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) => guarded(
                                    context,
                                    () async {
                                      if (v == 'block') {
                                        await widget.repo.block(p['id']);
                                      } else {
                                        await widget.repo.report(
                                          p['id'],
                                          'safety',
                                        );
                                      }
                                      if (mounted) {
                                        setState(() => removed.add(p['id']));
                                      }
                                    },
                                    success: s.t(
                                      'تم حفظ طلبك',
                                      'Request saved',
                                    ),
                                  ),
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'block',
                                      child: Text(s.t('حظر', 'Block')),
                                    ),
                                    PopupMenuItem(
                                      value: 'report',
                                      child: Text(
                                        s.t(
                                          'إبلاغ عن مخاوف سلامة',
                                          'Report safety concern',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              s.t(
                                'اهتمامات مشتركة: ${p['shared_interests']}',
                                'Shared interests: ${p['shared_interests']}',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => action(p, 'pass'),
                                    child: Text(s.t('تخطّي', 'Pass')),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () => action(p, 'like'),
                                    icon: const Icon(Icons.favorite_outline),
                                    label: Text(s.t('إعجاب', 'Like')),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: page == 0
                    ? null
                    : () {
                        page--;
                        reload();
                      },
                child: Text(s.t('السابق', 'Previous')),
              ),
              Text('${page + 1}'),
              TextButton(
                onPressed: () {
                  page++;
                  reload();
                },
                child: Text(s.t('التالي', 'Next')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
