import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../shared/app_controls.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';
import '../profiles/profile_fields.dart';

class SettingsScreen extends StatelessWidget {
  final NovaRepository repo;
  const SettingsScreen({super.key, required this.repo});
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(s.settings, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        AccountOverview(repo: repo),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: Text(s.t('تعديل ملفي وصوري', 'Edit my profile and photos')),
          onTap: () => context.go('/profile/edit'),
        ),
        ListTile(
          leading: const Icon(Icons.bookmark_outline),
          title: Text(s.t('مفضلتي الخاصة', 'My private favorites')),
          onTap: () => context.go('/favorites'),
        ),
        ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: Text(s.t('العضوية والمشتريات', 'Membership and purchases')),
          onTap: () => context.go('/plans'),
        ),
        ListTile(
          leading: const Icon(Icons.group_add_outlined),
          title: Text(s.t('دعواتي', 'My invitations')),
          onTap: () => context.go('/referrals'),
        ),
        const Divider(height: 32),
        Text(
          s.t('الأمان وتفضيلات التطبيق', 'Security and app preferences'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        ListTile(
          leading: const Icon(Icons.password),
          title: Text(s.t('تغيير كلمة المرور', 'Change password')),
          onTap: () => context.go('/password'),
        ),
        ListTile(
          leading: const Icon(Icons.tune),
          title: Text(
            s.t('تفضيلات الاكتشاف والعمر', 'Discovery and age preferences'),
          ),
          onTap: () => context.go('/filters'),
        ),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppControls(),
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
          title: Text(
            s.t('تصدير بيانات حسابي فقط', 'Export only my account data'),
          ),
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
        StaffEntry(repo: repo),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(s.t('تسجيل الخروج', 'Sign out')),
          onTap: () => guarded(context, repo.client.auth.signOut),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete_forever),
          title: Text(
            s.t('طلب حذف حسابي وبياناتي', 'Request account and data deletion'),
          ),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  s.t('طلب حذف الحساب؟', 'Request account deletion?'),
                ),
                content: Text(
                  s.t(
                    'سيُخفى ملفك ويُسجل طلب حذف بعد مهلة 7 أيام. التنفيذ يتطلب عامل حذف مخولًا ومراجعة الاحتفاظ للسلامة. يمكنك إلغاء الطلب خلال المهلة؛ لا تُحذف المحادثات فورًا.',
                    'Your profile will be hidden and a deletion request scheduled after a 7-day grace period. Execution requires an authorized deletion worker and safety retention review. You may cancel during the grace period; chats are not immediately deleted.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(s.t('إلغاء', 'Cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(s.t('تسجيل الطلب', 'Submit request')),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              await guarded(context, () async {
                await repo.requestDeletion();
                if (context.mounted) context.go('/');
              });
            }
          },
        ),
        DeletionRequestPanel(repo: repo),
      ],
    );
  }
}

class AccountOverview extends StatefulWidget {
  final NovaRepository repo;
  const AccountOverview({super.key, required this.repo});
  @override
  State<AccountOverview> createState() => _AccountOverviewState();
}

class _AccountOverviewState extends State<AccountOverview> {
  late Future<List<dynamic>> data = load();
  Future<List<dynamic>> load() async => [
    await widget.repo.profile(),
    await widget.repo.membership(),
  ];
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AsyncPane<List<dynamic>>(
      future: data,
      retry: () => setState(() {
        data = load();
      }),
      builder: (all) {
        final p = Map<String, dynamic>.from(all[0] ?? {}), m = all[1] as Map;
        final completion = ProfileFields.completion(p);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['display_name'] ?? '',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (p['username'] != null) Text('@${p['username']}'),
                const SizedBox(height: 12),
                Text(
                  s.t('معلومات حساب خاصة بك', 'Private account information'),
                ),
                SelectableText(
                  widget.repo.client.auth.currentUser?.email ?? '',
                ),
                const SizedBox(height: 12),
                Text(
                  s.t(
                    'اكتمال الملف: $completion٪',
                    'Profile completion: $completion%',
                  ),
                ),
                LinearProgressIndicator(value: completion / 100),
                const SizedBox(height: 12),
                Text(
                  s.t(
                    'الحقول الإضافية اختيارية؛ يمكنك استخدام الاكتشاف دون إكمالها.',
                    'Additional fields are optional; discovery works without completing them.',
                  ),
                ),
                Text(s.t('العضوية: ${m['tier']}', 'Membership: ${m['tier']}')),
                if (m['expires_at'] != null)
                  Text(
                    s.t(
                      'انتهاء الاستحقاق: ${m['expires_at']}',
                      'Entitlement expires: ${m['expires_at']}',
                    ),
                  ),
                Text(
                  p['verified'] == true
                      ? s.t('تمت مراجعة التوثيق', 'Verification reviewed')
                      : s.t(
                          'لم يُراجع توثيق الهوية',
                          'Identity verification not reviewed',
                        ),
                ),
                if (p['created_at'] != null)
                  Text(
                    s.t(
                      'عضو منذ ${p['created_at'].toString().substring(0, 10)}',
                      'Member since ${p['created_at'].toString().substring(0, 10)}',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StaffEntry extends StatefulWidget {
  final NovaRepository repo;
  const StaffEntry({super.key, required this.repo});
  @override
  State<StaffEntry> createState() => _StaffEntryState();
}

class _StaffEntryState extends State<StaffEntry> {
  late final Future<List<DbRow>> data = widget.repo.roles();
  @override
  Widget build(BuildContext context) => FutureBuilder<List<DbRow>>(
    future: data,
    builder: (context, snapshot) {
      if (!(snapshot.data ?? []).any(
        (r) => ['moderator', 'administrator'].contains(r['role']),
      )) {
        return const SizedBox.shrink();
      }
      return ListTile(
        leading: const Icon(Icons.admin_panel_settings_outlined),
        title: Text(
          Strings.of(context)
              .t('بوابة الإشراف المخوّلة', 'Authorized moderation portal'),
        ),
        onTap: () => context.go('/admin'),
      );
    },
  );
}

class DeletionRequestPanel extends StatefulWidget {
  final NovaRepository repo;
  const DeletionRequestPanel({super.key, required this.repo});
  @override
  State<DeletionRequestPanel> createState() => _DeletionRequestPanelState();
}

class _DeletionRequestPanelState extends State<DeletionRequestPanel> {
  late Future<DbRow?> data = widget.repo.client
      .from('account_deletion_requests')
      .select()
      .eq('user_id', widget.repo.uid)
      .maybeSingle();
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return FutureBuilder<DbRow?>(
      future: data,
      builder: (context, result) {
        if (result.data == null || result.data!['cancelled_at'] != null) {
          return const SizedBox.shrink();
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  s.t(
                    'يوجد طلب حذف محفوظ. التنفيذ بعد ${result.data!['execute_after']} ومراجعة مخولة.',
                    'Deletion requested. Execution after ${result.data!['execute_after']} and authorized review.',
                  ),
                ),
                TextButton(
                  onPressed: () => guarded(context, () async {
                    await widget.repo.requestDeletion(cancel: true);
                    if (mounted) {
                      setState(() {
                        data = Future.value(null);
                      });
                    }
                  }),
                  child: Text(
                    s.t('إلغاء طلب الحذف', 'Cancel deletion request'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
