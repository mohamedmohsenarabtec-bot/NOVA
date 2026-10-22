import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';

class PlansScreen extends StatefulWidget {
  final NovaRepository repo;
  const PlansScreen({super.key, required this.repo});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late Future<List<dynamic>> data = load();
  int months = 1;
  Future<List<dynamic>> load() async => [
    await widget.repo.plans(),
    widget.repo.client.auth.currentUser == null
        ? {'tier': 'free', 'trial_eligible': false}
        : await widget.repo.membership(),
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
        final rows = List<DbRow>.from(all[0]);
        final status = all[1] as Map;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              s.t(
                'مساحة أوسع، بنفس الاحترام',
                'More possibilities. The same respect.',
              ),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              s.t(
                'عضويتك: ${status['tier'].toString().toUpperCase()}',
                'Your membership: ${status['tier'].toString().toUpperCase()}',
              ),
            ),
            if (status['expires_at'] != null)
              Text(
                s.t(
                  'صالحة حتى ${status['expires_at']}',
                  'Valid until ${status['expires_at']}',
                ),
              ),
            const SizedBox(height: 16),
            Text(
              s.t(
                'معاينة مقترحة فقط. الأسعار بالجنيه المصري توضيحية وغير معتمدة. لا دفع، ولا تجديد تلقائي، ولا تجربة مفعلة.',
                'Proposal preview only. EGP prices are illustrative and unapproved. No payment, auto-renewal or active trial.',
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in [1, 3, 6, 12])
                  ChoiceChip(
                    label: Text(
                      s.t(
                        {1: 'شهري', 3: '3 أشهر', 6: '6 أشهر', 12: 'سنوي'}[m]!,
                        {
                          1: 'Monthly',
                          3: '3 months',
                          6: '6 months',
                          12: 'Annual',
                        }[m]!,
                      ),
                    ),
                    selected: months == m,
                    onSelected: (_) => setState(() => months = m),
                  ),
              ],
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  s.t(
                    'لم تُفعّل خطط مدفوعة بعد.',
                    'No paid plans are enabled yet.',
                  ),
                ),
              ),
            for (final p in rows.where(
              (p) => p['tier'] == 'free' || p['months'] == months,
            ))
              Card(
                margin: const EdgeInsets.symmetric(vertical: 12),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        p['tier'] == 'free'
                            ? 'FREE'
                            : 'NOVA ${p['tier'].toString().toUpperCase()}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        p['tier'] == 'free'
                            ? s.t('مجاني دائمًا', 'Always free')
                            : s.t(
                                'مقترح: ${(p['price_minor'] / 100).toStringAsFixed(2)} ${p['currency']} إجمالي ${p['months']} شهر',
                                'Proposed: ${(p['price_minor'] / 100).toStringAsFixed(2)} ${p['currency']} total for ${p['months']} months',
                              ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (p['tier'] != 'free')
                        Text(
                          s.t(
                            'ما يعادل ${(p['price_minor'] / 100 / p['months']).toStringAsFixed(2)} شهريًا. لا مبلغ مستحق الآن.',
                            'Equivalent to ${(p['price_minor'] / 100 / p['months']).toStringAsFixed(2)} monthly. Nothing payable now.',
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        s.t(
                          'ملف قابل للتعديل، 6 صور، مفضلة خاصة، تطابق ودردشة متبادلة، وحظر وإبلاغ مجاني للجميع.',
                          'Editable profile, 6 photos, private favorites, mutual matches/chat, block and report are free for everyone.',
                        ),
                      ),
                      Text(
                        s.t(
                          'حد الإعجابات اليومي: ${p['features']['daily_likes']}',
                          'Daily likes: ${p['features']['daily_likes']}',
                        ),
                      ),
                      if (p['features']['advanced_filters'] == true)
                        Text(
                          s.t(
                            'فلاتر إضافية مفروضة من الخادم عند استحقاق صالح',
                            'Server-enforced advanced filters with a valid entitlement',
                          ),
                        ),
                      if (p['features']['liked_you'] == true)
                        Text(
                          s.t(
                            'عرض المعجبين المسموح بهم عند استحقاق Premium صالح',
                            'Permitted liker identities with a valid Premium entitlement',
                          ),
                        ),
                      if (p['tier'] != 'free') ...[
                        const SizedBox(height: 12),
                        Text(
                          s.t(
                            'تجربة أولى مقترحة: ${p['trial_days']} أيام، معلقة حتى الاعتماد. أهلية حسابك: ${status['trial_eligible'] == true ? 'مبدئية' : 'غير متاحة'}؛ لا تبدأ الآن.',
                            'Proposed first trial: ${p['trial_days']} days, pending approval. Your eligibility: ${status['trial_eligible'] == true ? 'provisional' : 'unavailable'}; no trial starts now.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => guarded(
                            context,
                            () => widget.repo.ticket(
                              'Membership availability request: ${p['id']}',
                            ),
                            success: s.t(
                              'حُفظ طلب إشعارك بالإتاحة، دون أي اشتراك',
                              'Availability request saved; no subscription created',
                            ),
                          ),
                          child: Text(
                            s.t(
                              'أخبرني عند الإتاحة',
                              'Notify me when available',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(
                    s.t('استعادة مشتريات المتجر', 'Restore store purchases'),
                  ),
                  content: Text(
                    s.t(
                      'لا يوجد متجر دفع مربوط بهذه المعاينة. الاستعادة تتطلب سجلًا موثقًا من Apple أو Google؛ لم يُغير استحقاقك.',
                      'No store billing provider is connected to this preview. Restore requires a verified Apple or Google transaction; your entitlement has not changed.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text(s.t('فهمت', 'Understood')),
                    ),
                  ],
                ),
              ),
              child: Text(
                s.t('حالة استعادة المشتريات', 'Restore purchase status'),
              ),
            ),
            Text(
              s.t(
                'لا توجد إعلانات داخل المحادثات. لا تُباع علامة التوثيق.',
                'No ads in conversations. Verification is never sold.',
              ),
            ),
          ],
        );
      },
    );
  }
}
