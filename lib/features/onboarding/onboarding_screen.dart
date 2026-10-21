import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../shared/app_controls.dart';
import '../../shared/brand.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';

class OnboardingScreen extends StatefulWidget {
  final NovaRepository repo;
  final DbRow? initial;
  final VoidCallback onComplete;
  const OnboardingScreen({
    super.key,
    required this.repo,
    this.initial,
    required this.onComplete,
  });
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final name = TextEditingController();
  int step = 0;
  bool busy = false;
  String gender = 'woman', preference = 'man', intention = 'serious';
  final interests = <String>{};
  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    if (p != null) {
      name.text = p['display_name'] ?? '';
      step = (p['onboarding_step'] as int? ?? 0).clamp(0, 4);
      gender = p['gender'] ?? gender;
      preference = p['seeking_gender'] ?? preference;
      intention = p['intention'] ?? intention;
      interests.addAll(List<String>.from(p['interests'] ?? []));
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> next() async {
    if (name.text.trim().length < 2) return;
    setState(() => busy = true);
    await guarded(context, () async {
      await widget.repo.saveProfile({
        'display_name': name.text.trim(),
        'gender': gender,
        'seeking_gender': preference,
        'intention': intention,
        'interests': interests.toList(),
        'onboarding_step': step == 4 ? 5 : step + 1,
        'onboarding_complete': step == 4,
      });
      if (!mounted) return;
      if (step == 4) {
        widget.onComplete();
      } else {
        setState(() => step++);
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final titles = [
      s.t('لنبدأ باسمك', 'Start with your name'),
      s.t('من تحب أن تقابل؟', 'Who would you like to meet?'),
      s.t('ما نيتك من التعارف؟', 'What brings you here?'),
      s.t('الأشياء التي تشبهك', 'The things that make you, you'),
      s.t('أنت جاهز للبداية', 'Ready for a new beginning'),
    ];
    Widget choices(
      Map<String, String> options,
      String selected,
      ValueChanged<String> change,
    ) => Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.entries
          .map(
            (e) => ChoiceChip(
              label: Text(e.value),
              selected: selected == e.key,
              onSelected: (_) => setState(() => change(e.key)),
            ),
          )
          .toList(),
    );
    final genders = {
      'woman': s.t('امرأة', 'Woman'),
      'man': s.t('رجل', 'Man'),
      'nonbinary': s.t('غير ثنائي', 'Nonbinary'),
    };
    return Scaffold(
      appBar: AppBar(
        title: const NovaLogo(symbolOnly: true),
        actions: [
          const AppControls(),
          IconButton(
            tooltip: s.t('خروج', 'Sign out'),
            onPressed: () => widget.repo.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              const Center(child: NovaLogo()),
              TextButton.icon(
                onPressed: () => context.go('/password'),
                icon: const Icon(Icons.password),
                label: Text(s.t('تغيير كلمة المرور', 'Change password')),
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: (step + 1) / 5,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 36),
              Text(
                titles[step],
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                s.t(
                  'خطوات بسيطة، وباقي التفاصيل على راحتك.',
                  'A few essentials now. More details when you feel ready.',
                ),
              ),
              const SizedBox(height: 32),
              if (step == 0)
                TextField(
                  controller: name,
                  maxLength: 40,
                  decoration: InputDecoration(
                    labelText: s.t(
                      'اسم العرض • حرفان على الأقل',
                      'Display name • at least 2 characters',
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              if (step == 1) ...[
                Text(s.t('هويتك', 'Your gender')),
                const SizedBox(height: 12),
                choices(genders, gender, (v) => gender = v),
                const SizedBox(height: 24),
                Text(s.t('تفضيل الاكتشاف', 'Discovery preference')),
                const SizedBox(height: 12),
                choices(
                  {...genders, 'any': s.t('الجميع', 'Everyone')},
                  preference,
                  (v) => preference = v,
                ),
              ],
              if (step == 2)
                choices(
                  {
                    'marriage': s.t('زواج', 'Marriage'),
                    'serious': s.t('علاقة جادة', 'Serious relationship'),
                    'dating': s.t('تعارف', 'Dating'),
                    'friendship': s.t('صداقة', 'Friendship'),
                    'social': s.t('اكتشاف اجتماعي', 'Social discovery'),
                  },
                  intention,
                  (v) => intention = v,
                ),
              if (step == 3)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children:
                      {
                            'books': s.t('القراءة', 'Books'),
                            'music': s.t('الموسيقى', 'Music'),
                            'travel': s.t('السفر', 'Travel'),
                            'cooking': s.t('الطبخ', 'Cooking'),
                            'art': s.t('الفن', 'Art'),
                            'fitness': s.t('الرياضة', 'Fitness'),
                            'nature': s.t('الطبيعة', 'Nature'),
                            'games': s.t('الألعاب', 'Games'),
                          }.entries
                          .map(
                            (e) => FilterChip(
                              label: Text(e.value),
                              selected: interests.contains(e.key),
                              onSelected: (value) => setState(
                                () => value
                                    ? interests.add(e.key)
                                    : interests.remove(e.key),
                              ),
                            ),
                          )
                          .toList(),
                ),
              if (step == 4)
                EmptyState(
                  icon: Icons.spa_outlined,
                  title: s.t('مساحة لتكون على طبيعتك', 'Room to be yourself'),
                  body: s.t(
                    'يمكنك البدء دون صورة. رفع الصور قيد التطوير ولن نعرضك كحساب موثّق دون مراجعة حقيقية.',
                    'You may start without a photo. Photo uploads are under development. Verification requires a real review.',
                  ),
                ),
              const SizedBox(height: 36),
              FilledButton(
                onPressed: busy || name.text.trim().length < 2 ? null : next,
                child: Text(
                  busy
                      ? s.t('جارٍ الحفظ…', 'Saving…')
                      : step == 4
                      ? s.discover
                      : s.t('حفظ ومتابعة', 'Save and continue'),
                ),
              ),
              if (step > 0)
                TextButton(
                  onPressed: busy ? null : () => setState(() => step--),
                  child: Text(s.t('رجوع', 'Back')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
