import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';
import '../profiles/profile_card.dart';

class DiscoverScreen extends StatefulWidget {
  final NovaRepository repo;
  const DiscoverScreen({super.key, required this.repo});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late Future<List<DbRow>> data = widget.repo.discover();
  int page = 0;
  final removed = <String>{};
  void reload() => setState(() {
    removed.clear();
    data = widget.repo.discover(page: page);
  });
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  s.t('أشخاص، بنية واضحة', 'People, with intention'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: s.t('فلاتر الاكتشاف', 'Discovery filters'),
                onPressed: () => context.go('/filters'),
                icon: const Icon(Icons.tune),
              ),
              IconButton(
                tooltip: s.t('تحديث', 'Refresh'),
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
            loading: const DiscoverySkeleton(),
            builder: (rows) {
              final visible = rows
                  .where((p) => !removed.contains(p['id']))
                  .toList();
              if (visible.isEmpty) {
                return EmptyState(
                  icon: Icons.explore_outlined,
                  title: s.t(
                    'العلاقات الجميلة تحتاج وقتًا',
                    'Good connections take time',
                  ),
                  body: s.t(
                    'لا توجد ملفات جديدة مؤهلة وفق تفضيلاتكما الآن. قد تكون الملفات متطابقة بالفعل أو مستبعدة بفلاتر أو حظر أو بلاغ. راجع المحادثات أو عدّل فلاترك؛ لن نعرض أشخاصًا وهميين.',
                    'No new eligible profiles meet reciprocal preferences right now. Existing profiles may already be matched or excluded by filters, blocks or reports. Check Chats or adjust filters; we never invent people.',
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= 760;
                  final columns = wide
                      ? (box.maxWidth / 380).floor().clamp(2, 4)
                      : 1;
                  final width =
                      (box.maxWidth - 32 - (columns - 1) * 12) / columns;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final p in visible)
                            SizedBox(
                              width: width,
                              child: ProfileCard(
                                key: ValueKey(p['id']),
                                repo: widget.repo,
                                profile: p,
                                onAction: () =>
                                    setState(() => removed.add(p['id'])),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
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

class DiscoverySkeleton extends StatelessWidget {
  const DiscoverySkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: Strings.of(context).t('تحميل الملفات', 'Loading profiles'),
    child: ExcludeSemantics(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (var i = 0; i < 2; i++)
            Card(
              child: SizedBox(
                height: 280,
                child: Center(
                  child: LinearProgressIndicator(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
