import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../shared/app_controls.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';
import '../profiles/profile_fields.dart';

class FilterScreen extends StatefulWidget {
  final NovaRepository repo;
  const FilterScreen({super.key, required this.repo});
  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late Future<DbRow?> data = load();
  final city = TextEditingController(),
      interests = TextEditingController(),
      languages = TextEditingController();
  RangeValues ages = const RangeValues(18, 80);
  String gender = 'any', intention = '';
  bool photo = false, verified = false, advanced = false, busy = false;
  double completion = 0;
  Future<DbRow?> load() async {
    final p = await widget.repo.profile();
    final m = await widget.repo.membership();
    if (p != null) {
      final f = p['filters'] as Map? ?? {};
      city.text = f['city'] ?? '';
      gender = f['gender'] ?? 'any';
      intention = f['intention'] ?? '';
      ages = RangeValues(
        (p['min_age'] as num).toDouble(),
        (p['max_age'] as num).toDouble(),
      );
      interests.text = (f['interests'] as List? ?? []).join(', ');
      languages.text = (f['languages'] as List? ?? []).join(', ');
      photo = f['has_photo'] == true;
      verified = f['verified'] == true;
      completion = (f['min_completion'] as num? ?? 0).toDouble();
      advanced = m['tier'] != 'free';
    }
    return p;
  }

  @override
  void dispose() {
    city.dispose();
    interests.dispose();
    languages.dispose();
    super.dispose();
  }

  Future<void> apply({bool reset = false}) async {
    setState(() => busy = true);
    await guarded(context, () async {
      await widget.repo.saveProfile({
        'min_age': reset ? 18 : ages.start.round(),
        'max_age': reset ? 80 : ages.end.round(),
      });
      await widget.repo.saveFilters(
        reset
            ? {}
            : {
                'city': city.text.trim(),
                'gender': gender,
                'intention': intention,
                if (advanced) ...{
                  'interests': ProfileFields.values(interests.text),
                  'languages': ProfileFields.values(languages.text),
                  'has_photo': photo,
                  'verified': verified,
                  'min_completion': completion.round(),
                },
              },
      );
      if (mounted) context.go('/');
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text(s.t('فلاتر الاكتشاف', 'Discovery filters')),
        actions: const [AppControls()],
      ),
      body: AsyncPane<DbRow?>(
        future: data,
        retry: () => setState(() {
          data = load();
        }),
        builder: (_) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  s.t(
                    'العمر: ${ages.start.round()}–${ages.end.round()}',
                    'Age: ${ages.start.round()}–${ages.end.round()}',
                  ),
                ),
                RangeSlider(
                  values: ages,
                  min: 18,
                  max: 120,
                  divisions: 102,
                  onChanged: (v) => setState(() => ages = v),
                ),
                TextField(
                  controller: city,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: s.t(
                      'مدينة أو منطقة (اتركها فارغة للجميع)',
                      'City or region (leave empty for all)',
                    ),
                    helperText: s.t(
                      'بحث إقليمي دون GPS أو تتبع دقيق.',
                      'Regional search without GPS or precise tracking.',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: gender,
                  decoration: InputDecoration(
                    labelText: s.t('النوع', 'Gender'),
                  ),
                  items:
                      {
                            'any': s.t(
                              'الجميع ضمن تفضيلاتي',
                              'Everyone within my preferences',
                            ),
                            'woman': s.t('نساء', 'Women'),
                            'man': s.t('رجال', 'Men'),
                            'nonbinary': s.t('غير ثنائي', 'Nonbinary'),
                          }.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => gender = v!,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: intention,
                  decoration: InputDecoration(
                    labelText: s.t('النية', 'Intention'),
                  ),
                  items:
                      {
                            '': s.t(
                              'وفق توافق الملفين',
                              'Use reciprocal compatibility',
                            ),
                            'serious': s.t('علاقة جادة', 'Serious'),
                            'marriage': s.t('زواج', 'Marriage'),
                            'friendship': s.t('صداقة', 'Friendship'),
                            'dating': s.t('تعارف', 'Dating'),
                            'social': s.t('تواصل اجتماعي', 'Social'),
                          }.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => intention = v!,
                ),
                const SizedBox(height: 24),
                Text(
                  s.t(
                    'فلاتر إضافية • Plus وPremium',
                    'Advanced filters • Plus and Premium',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (!advanced)
                  Text(
                    s.t(
                      'تتوفر عند وجود استحقاق صالح على الخادم. الشراء غير مفعل.',
                      'Available with a valid server entitlement. Purchases are not enabled.',
                    ),
                  ),
                TextField(
                  enabled: advanced,
                  controller: interests,
                  decoration: InputDecoration(
                    labelText: s.t('اهتمامات مشتركة', 'Shared interests'),
                  ),
                ),
                TextField(
                  enabled: advanced,
                  controller: languages,
                  decoration: InputDecoration(
                    labelText: s.t('لغات', 'Languages'),
                  ),
                ),
                SwitchListTile(
                  title: Text(s.t('صور ملف متاحة', 'Profile photo available')),
                  value: photo,
                  onChanged: advanced ? (v) => setState(() => photo = v) : null,
                ),
                SwitchListTile(
                  title: Text(
                    s.t('توثيق تمت مراجعته فقط', 'Genuinely verified only'),
                  ),
                  value: verified,
                  onChanged: advanced
                      ? (v) => setState(() => verified = v)
                      : null,
                ),
                Text(
                  s.t(
                    'اكتمال الملف: ${completion.round()}٪',
                    'Profile completion: ${completion.round()}%',
                  ),
                ),
                Slider(
                  value: completion,
                  min: 0,
                  max: 100,
                  divisions: 10,
                  onChanged: advanced
                      ? (v) => setState(() => completion = v)
                      : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : () => apply(),
                  child: Text(s.t('تطبيق وحفظ', 'Apply and save')),
                ),
                TextButton(
                  onPressed: busy ? null : () => apply(reset: true),
                  child: Text(s.t('إعادة ضبط', 'Reset')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
