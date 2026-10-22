import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';

class ReferralsScreen extends StatefulWidget {
  final NovaRepository repo;
  const ReferralsScreen({super.key, required this.repo});
  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  late Future<DbRow> data = widget.repo.referrals();
  final code = TextEditingController(
    text: Uri.base.queryParameters['invite'] ?? '',
  );
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  void reload() => setState(() {
    data = widget.repo.referrals();
  });
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AsyncPane<DbRow>(
      future: data,
      retry: reload,
      builder: (r) {
        final rules = r['reward_rules'] as Map? ?? {};
        final extraLikes = rules['extra_likes'] ?? 25;
        final rewardDays = rules['days'] ?? 7;
        final minimumDays = rules['minimum_age_days'] ?? 7;
        final monthlyCap = rules['monthly_cap'] ?? 3;
        final link =
            'https://mohamedmohsenarabtec-bot.github.io/NOVA/?invite=${r['code']}#/referrals';
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              s.t('بدايات أجمل مع أصدقائك', 'New beginnings with friends'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(s.t('رمز دعوتك', 'Your invitation code')),
            SelectableText(
              r['code'],
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => guarded(
                    context,
                    () => Clipboard.setData(ClipboardData(text: link)),
                    success: s.t('نُسخ الرابط', 'Link copied'),
                  ),
                  icon: const Icon(Icons.copy),
                  label: Text(s.t('نسخ الرابط', 'Copy link')),
                ),
                Builder(
                  builder: (buttonContext) => FilledButton.icon(
                    onPressed: () => guarded(context, () async {
                      final box = buttonContext.findRenderObject() as RenderBox;
                      await SharePlus.instance.share(
                        ShareParams(
                          text: link,
                          sharePositionOrigin:
                              box.localToGlobal(Offset.zero) & box.size,
                        ),
                      );
                    }),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(s.t('مشاركة', 'Share')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              s.t(
                'معلقة: ${r['pending']} • مؤهلة: ${r['qualified']} • مُكافأة: ${r['rewarded']}',
                'Pending: ${r['pending']} • Qualified: ${r['qualified']} • Rewarded: ${r['rewarded']}',
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  s.t(
                    'المكافأة المقترحة: $extraLikes إعجابًا إضافيًا يوميًا لمدة $rewardDays أيام، بحد $monthlyCap مكافآت كل 30 يومًا. يلزم حساب جديد مؤهل عمره $minimumDays أيام، وملف مكتمل أساسيًا، وتطابق مشروع مع شخص آخر، ومراجعة مخولة. فتح الرابط وحده لا يمنح شيئًا. المكافآت معلقة حتى اعتماد المالك، ولا يُكشف لك بريد المدعوين.',
                    'Proposed reward: $extraLikes extra daily likes for $rewardDays days, capped at $monthlyCap rewards per 30 days. A legitimate new account aged $minimumDays days, basic completed profile, mutual match with another person, and authorized review are required. Opening a link earns nothing. Rewards await business approval; invitee emails are never disclosed.',
                  ),
                ),
              ),
            ),
            if (r['claimed'] != true) ...[
              const SizedBox(height: 24),
              TextField(
                controller: code,
                maxLength: 16,
                decoration: InputDecoration(
                  labelText: s.t(
                    'لديك رمز دعوة؟ خلال أول 7 أيام',
                    'Have an invitation? Within your first 7 days',
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => guarded(
                  context,
                  () async {
                    await widget.repo.claimReferral(code.text.trim());
                    reload();
                  },
                  success: s.t(
                    'حُفظت الدعوة، دون منح مكافأة فورية',
                    'Invitation saved; no immediate reward granted',
                  ),
                ),
                child: Text(s.t('استخدام الرمز', 'Use invitation')),
              ),
            ],
          ],
        );
      },
    );
  }
}
