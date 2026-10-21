import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';

class AdminScreen extends StatefulWidget {
  final NovaRepository repo;
  const AdminScreen({super.key, required this.repo});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<DbRow>> roles = widget.repo.roles();
  late Future<List<DbRow>> reports = widget.repo.queue();
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
        title: Text(s.t('NOVA • الإشراف', 'NOVA • Moderation')),
      ),
      body: AsyncPane<List<DbRow>>(
        future: roles,
        retry: () => setState(() => roles = widget.repo.roles()),
        builder: (roles) {
          if (!roles.any(
            (r) => ['moderator', 'administrator'].contains(r['role']),
          )) {
            return EmptyState(
              icon: Icons.lock_outline,
              title: s.t('الوصول مقيّد', 'Restricted access'),
              body: s.t(
                'يلزم تعيين صلاحية الموظف من الخادم.',
                'Staff access must be granted on the server.',
              ),
            );
          }
          return AsyncPane<List<DbRow>>(
            future: reports,
            retry: () => setState(() => reports = widget.repo.queue()),
            builder: (rows) => rows.isEmpty
                ? EmptyState(
                    icon: Icons.verified_user_outlined,
                    title: s.t('لا توجد بلاغات معلقة', 'No pending reports'),
                    body: s.t(
                      'تُسجل جميع قرارات الإشراف في سجل التدقيق.',
                      'All moderation decisions are audited.',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: rows
                        .map(
                          (r) => Card(
                            child: ListTile(
                              title: Text(r['category']),
                              subtitle: Text(
                                '${r['subject_id']}\n${r['created_at']}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (decision) =>
                                    guarded(context, () async {
                                      await widget.repo.moderate(
                                        r['id'],
                                        decision,
                                      );
                                      if (mounted) {
                                        setState(
                                          () => reports = widget.repo.queue(),
                                        );
                                      }
                                    }),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'dismiss',
                                    child: Text(s.t('إغلاق', 'Dismiss')),
                                  ),
                                  PopupMenuItem(
                                    value: 'suspend',
                                    child: Text(
                                      s.t('تعليق الحساب', 'Suspend account'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          );
        },
      ),
    );
  }
}
