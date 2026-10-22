import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../shared/app_controls.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';
import 'profile_fields.dart';
import 'photo_editor.dart';

class ProfileEditor extends StatefulWidget {
  final NovaRepository repo;
  const ProfileEditor({super.key, required this.repo});
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final form = GlobalKey<FormState>();
  final inputs = <String, TextEditingController>{};
  final publicFields = <String>{};
  late final Future<DbRow?> data = load();
  DateTime? birth;
  String gender = 'woman', audience = 'man', intention = 'serious';
  bool dirty = false, busy = false, visible = true;
  Future<DbRow?> load() async {
    final p = await widget.repo.profile();
    if (p == null) return p;
    for (final key in ['display_name', 'username', 'city', 'bio']) {
      inputs[key] = TextEditingController(text: p[key]?.toString() ?? '');
    }
    for (final key in ['languages', 'interests']) {
      inputs[key] = TextEditingController(
        text: (p[key] as List? ?? []).join(', '),
      );
    }
    final details = Map<String, dynamic>.from(p['details'] ?? {});
    for (final key in ProfileFields.details.keys) {
      inputs[key] = TextEditingController(text: details[key]?.toString() ?? '');
    }
    birth = DateTime.parse(p['birth_date']);
    gender = p['gender'];
    audience = p['seeking_gender'];
    intention = p['intention'];
    visible = p['visible'] == true;
    publicFields.addAll(List<String>.from(p['public_fields'] ?? []));
    return p;
  }

  @override
  void dispose() {
    for (final input in inputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> leave() async {
    final s = Strings.of(context);
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(s.t('تجاهل التغييرات؟', 'Discard changes?')),
          content: Text(
            s.t(
              'التغييرات غير المحفوظة ستُفقد.',
              'Unsaved changes will be lost.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(s.t('متابعة التعديل', 'Keep editing')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(s.t('تجاهل', 'Discard')),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (!mounted) return;
    setState(() => dirty = false);
    context.go('/');
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    await guarded(context, () async {
      final details = {
        for (final key in ProfileFields.details.keys)
          if (inputs[key]!.text.trim().isNotEmpty)
            key: inputs[key]!.text.trim(),
      };
      await widget.repo.saveProfile({
        for (final key in ['display_name', 'username', 'city', 'bio'])
          key: inputs[key]!.text.trim(),
        'birth_date': birth!.toIso8601String().substring(0, 10),
        'gender': gender,
        'seeking_gender': audience,
        'intention': intention,
        'visible': visible,
        'languages': ProfileFields.values(inputs['languages']!.text),
        'interests': ProfileFields.values(inputs['interests']!.text),
        'details': details,
        'public_fields': publicFields.toList(),
      });
      if (mounted) setState(() => dirty = false);
    }, success: Strings.of(context).t('تم حفظ ملفك', 'Profile saved'));
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: leave),
          title: Text(s.t('ملفي العام', 'My public profile')),
          actions: const [AppControls()],
        ),
        body: AsyncPane<DbRow?>(
          future: data,
          retry: () => context.go('/'),
          builder: (p) {
            if (p == null) return Center(child: Text(s.error));
            Widget field(
              String key,
              String ar,
              String en, {
              int max = 100,
              int lines = 1,
              bool privacy = true,
            }) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                children: [
                  TextFormField(
                    controller: inputs[key],
                    maxLength: max,
                    maxLines: lines,
                    onChanged: (_) => setState(() => dirty = true),
                    decoration: InputDecoration(labelText: s.t(ar, en)),
                    validator: (v) =>
                        key == 'display_name' &&
                            ProfileFields.validateName(v ?? '') != null
                        ? s.t(
                            'استخدم اسمًا من 2 إلى 40 حرفًا',
                            'Use a name with 2–40 characters',
                          )
                        : key == 'username' &&
                              (v ?? '').isNotEmpty &&
                              !RegExp(r'^[a-z][a-z0-9_]{2,23}$').hasMatch(v!)
                        ? s.t(
                            '3–24 حرفًا لاتينيًا صغيرًا أو رقمًا أو _، يبدأ بحرف',
                            '3–24 lowercase letters, digits or _, starting with a letter',
                          )
                        : null,
                  ),
                  if (privacy)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        s.t(
                          'إظهار هذا الحقل في الملف',
                          'Show this field on my profile',
                        ),
                      ),
                      value: publicFields.contains(key),
                      onChanged: (v) => setState(() {
                        dirty = true;
                        v == true
                            ? publicFields.add(key)
                            : publicFields.remove(key);
                      }),
                    ),
                ],
              ),
            );
            Widget choice(
              String label,
              Map<String, String> values,
              String selected,
              ValueChanged<String> change,
            ) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: InputDecoration(labelText: label),
                items: values.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        dirty = true;
                        change(v!);
                      }),
              ),
            );
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      s.t(
                        'ملف يشبهك، بالقدر الذي تختاره',
                        'Your story, on your terms',
                      ),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.t(
                        'الحقول الإضافية اختيارية. بريدك وتاريخ ميلادك وتفضيلاتك لا تظهر للآخرين.',
                        'Additional fields are optional. Email, birth date and preferences remain private.',
                      ),
                    ),
                    const SizedBox(height: 24),
                    PhotoEditor(repo: widget.repo),
                    const Divider(height: 40),
                    Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          field(
                            'display_name',
                            'الاسم الظاهر',
                            'Display name',
                            max: 40,
                            privacy: false,
                          ),
                          field(
                            'username',
                            'اسم المستخدم (اختياري)',
                            'Username (optional)',
                            max: 24,
                          ),
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () async {
                                    final now = DateTime.now();
                                    final value = await showDatePicker(
                                      context: context,
                                      initialDate: birth!,
                                      firstDate: DateTime(
                                        now.year - 120,
                                        now.month,
                                        now.day,
                                      ),
                                      lastDate: DateTime(
                                        now.year - 18,
                                        now.month,
                                        now.day,
                                      ),
                                    );
                                    if (value != null) {
                                      setState(() {
                                        birth = value;
                                        dirty = true;
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.cake_outlined),
                            label: Text(
                              s.t(
                                'تاريخ الميلاد الخاص: ${birth!.toIso8601String().substring(0, 10)}',
                                'Private birth date: ${birth!.toIso8601String().substring(0, 10)}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          field(
                            'city',
                            'المدينة أو المنطقة العامة',
                            'City or broad region',
                            max: 80,
                          ),
                          field(
                            'bio',
                            'نبذة عني',
                            'About me',
                            max: 600,
                            lines: 4,
                          ),
                          choice(
                            s.t(
                              'النوع (خاص افتراضيًا)',
                              'Gender (private by default)',
                            ),
                            {
                              'woman': s.t('امرأة', 'Woman'),
                              'man': s.t('رجل', 'Man'),
                              'nonbinary': s.t('غير ثنائي', 'Nonbinary'),
                            },
                            gender,
                            (v) => gender = v,
                          ),
                          choice(
                            s.t(
                              'أفضّل التعرف على (خاص)',
                              'Interested in (private)',
                            ),
                            {
                              'woman': s.t('نساء', 'Women'),
                              'man': s.t('رجال', 'Men'),
                              'nonbinary': s.t('غير ثنائي', 'Nonbinary'),
                              'any': s.t('الجميع', 'Everyone'),
                            },
                            audience,
                            (v) => audience = v,
                          ),
                          choice(
                            s.t('النية من التعارف', 'Relationship intention'),
                            {
                              'serious': s.t(
                                'علاقة جادة',
                                'Serious relationship',
                              ),
                              'marriage': s.t('زواج', 'Marriage'),
                              'friendship': s.t('صداقة', 'Friendship'),
                              'dating': s.t('تعارف', 'Dating'),
                              'social': s.t(
                                'تواصل اجتماعي',
                                'Social connection',
                              ),
                            },
                            intention,
                            (v) => intention = v,
                          ),
                          SwitchListTile(
                            title: Text(
                              s.t(
                                'إظهار النية في ملفي',
                                'Show intention on my profile',
                              ),
                            ),
                            value: publicFields.contains('intention'),
                            onChanged: (v) => setState(() {
                              dirty = true;
                              v
                                  ? publicFields.add('intention')
                                  : publicFields.remove('intention');
                            }),
                          ),
                          field(
                            'languages',
                            'اللغات، مفصولة بفواصل',
                            'Languages, separated by commas',
                            max: 200,
                          ),
                          field(
                            'interests',
                            'الاهتمامات والهوايات، مفصولة بفواصل',
                            'Interests and hobbies, separated by commas',
                            max: 200,
                          ),
                          for (final e in ProfileFields.details.entries)
                            field(
                              e.key,
                              e.value[0],
                              e.value[1],
                              max: 400,
                              lines: 2,
                            ),
                          SwitchListTile(
                            title: Text(
                              s.t('الظهور في الاكتشاف', 'Visible in discovery'),
                            ),
                            value: visible,
                            onChanged: (v) => setState(() {
                              visible = v;
                              dirty = true;
                            }),
                          ),
                          FilledButton(
                            onPressed: busy || !dirty ? null : save,
                            child: Text(
                              busy
                                  ? s.t('جارٍ الحفظ…', 'Saving…')
                                  : s.t('حفظ الملف', 'Save profile'),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
