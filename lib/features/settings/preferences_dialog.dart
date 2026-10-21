import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';

Future<void> editPreferences(BuildContext context, NovaRepository repo) =>
    guarded(context, () async {
      final profile = await repo.profile();
      if (!context.mounted || profile == null) return;
      var ages = RangeValues(
        (profile['min_age'] as num).toDouble(),
        (profile['max_age'] as num).toDouble(),
      );
      var seeking = profile['seeking_gender'] as String;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) {
            final s = Strings.of(context);
            return AlertDialog(
              title: Text(s.t('تفضيلات الاكتشاف', 'Discovery preferences')),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.t(
                        'العمر: ${ages.start.round()} – ${ages.end.round()}',
                        'Age: ${ages.start.round()} – ${ages.end.round()}',
                      ),
                    ),
                    RangeSlider(
                      values: ages,
                      min: 18,
                      max: 120,
                      divisions: 102,
                      onChanged: (v) => update(() => ages = v),
                    ),
                    DropdownButton<String>(
                      value: seeking,
                      isExpanded: true,
                      items:
                          {
                                'woman': s.t('نساء', 'Women'),
                                'man': s.t('رجال', 'Men'),
                                'nonbinary': s.t('غير ثنائي', 'Nonbinary'),
                                'any': s.t('الجميع', 'Everyone'),
                              }.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => update(() => seeking = v!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(s.t('إلغاء', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => guarded(context, () async {
                    await repo.saveProfile({
                      'min_age': ages.start.round(),
                      'max_age': ages.end.round(),
                      'seeking_gender': seeking,
                    });
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  }),
                  child: Text(s.t('حفظ', 'Save')),
                ),
              ],
            );
          },
        ),
      );
    });
