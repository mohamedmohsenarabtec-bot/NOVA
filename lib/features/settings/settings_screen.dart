import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';
import 'preferences_dialog.dart';

class SettingsScreen extends StatelessWidget {
  final NovaRepository repo;
  final VoidCallback toggleTheme;
  const SettingsScreen({
    super.key,
    required this.repo,
    required this.toggleTheme,
  });
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(s.settings, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.tune),
          title: Text(
            s.t('تفضيلات الاكتشاف والعمر', 'Discovery and age preferences'),
          ),
          onTap: () => editPreferences(context, repo),
        ),
        ListTile(
          leading: const Icon(Icons.contrast),
          title: Text(s.t('تغيير المظهر', 'Switch theme')),
          onTap: toggleTheme,
        ),
        ListTile(
          leading: const Icon(Icons.visibility_outlined),
          title: Text(
            s.t('إخفاء ملفي من الاكتشاف', 'Hide my profile from discovery'),
          ),
          onTap: () => guarded(
            context,
            () => repo.saveProfile({'visible': false}),
            success: s.t('أُخفي ملفك', 'Profile hidden'),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.visibility),
          title: Text(
            s.t('إظهار ملفي في الاكتشاف', 'Show my profile in discovery'),
          ),
          onTap: () => guarded(
            context,
            () => repo.saveProfile({'visible': true}),
            success: s.t('أصبح ملفك مرئيًا', 'Profile visible'),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.block),
          title: Text(s.t('الحسابات المحظورة', 'Blocked accounts')),
          onTap: () => guarded(context, () async {
            final blocks = await repo.blocks();
            if (!context.mounted) return;
            await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(s.t('المحظورون', 'Blocked accounts')),
                content: SizedBox(
                  width: 400,
                  child: blocks.isEmpty
                      ? Text(
                          s.t('لا توجد حسابات محظورة', 'No blocked accounts'),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: blocks
                              .map(
                                (b) => ListTile(
                                  title: Text(b['target_id']),
                                  trailing: TextButton(
                                    onPressed: () => guarded(context, () async {
                                      await repo.unblock(b['target_id']);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    }),
                                    child: Text(s.t('إلغاء الحظر', 'Unblock')),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ),
            );
          }),
        ),
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: Text(
            s.t('السلامة وإرشادات المجتمع', 'Safety and community guidelines'),
          ),
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(s.t('سلامتك أولًا', 'Your safety comes first')),
              content: Text(
                s.t(
                  'لا ترسل أموالًا أو وثائق حساسة. التقِ في مكان عام وأخبر شخصًا تثق به. احترم الرفض والخصوصية. التحرش والاحتيال واستغلال القاصرين ممنوع. استخدم الحظر والإبلاغ عند الحاجة.',
                  'Never send money or sensitive documents. Meet in public and tell someone you trust. Respect consent and privacy. Harassment, fraud and exploitation of minors are prohibited. Use block and report when needed.',
                ),
              ),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.support_agent),
          title: Text(s.t('الدعم والاستئناف', 'Support and appeals')),
          onTap: () async {
            final input = TextEditingController();
            await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(s.t('كيف نساعدك؟', 'How can we help?')),
                content: TextField(
                  controller: input,
                  maxLength: 2000,
                  maxLines: 4,
                ),
                actions: [
                  TextButton(
                    onPressed: () => guarded(context, () async {
                      if (input.text.trim().isEmpty) return;
                      await repo.ticket(input.text.trim());
                      if (context.mounted) Navigator.pop(context);
                    }),
                    child: Text(s.t('إرسال', 'Send')),
                  ),
                ],
              ),
            );
            input.dispose();
          },
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: Text(s.t('تصدير بياناتي', 'Export my data')),
          onTap: () => guarded(context, () async {
            final data = await repo.exportData();
            if (context.mounted) {
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    s.t('انسخ بياناتك بأمان', 'Copy your data securely'),
                  ),
                  content: SingleChildScrollView(
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(data),
                    ),
                  ),
                ),
              );
            }
          }),
        ),
        ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined),
          title: Text(s.t('بوابة الموظفين', 'Staff portal')),
          onTap: () => context.go('/admin'),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(s.t('تسجيل الخروج', 'Sign out')),
          onTap: () => guarded(context, repo.client.auth.signOut),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete_forever),
          title: Text(s.t('حذف حسابي وبياناتي', 'Delete my account and data')),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(s.t('حذف نهائي؟', 'Delete permanently?')),
                content: Text(
                  s.t(
                    'سيُحذف الحساب وملفه ومحادثاته. لا يمكن التراجع عن هذا الإجراء.',
                    'Your account, profile and conversations will be deleted. This cannot be undone.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(s.t('إلغاء', 'Cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(s.t('حذف نهائي', 'Delete permanently')),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              await guarded(context, () async {
                await repo.deleteAccount();
                await repo.client.auth.signOut();
              });
            }
          },
        ),
      ],
    );
  }
}
