import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';

Future<void> showProfileDetail(BuildContext context, DbRow profile) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final s = Strings.of(context);
        final intentions = {
          'marriage': s.t('زواج', 'Marriage'),
          'serious': s.t('علاقة جادة', 'Serious relationship'),
          'dating': s.t('تعارف', 'Dating'),
          'friendship': s.t('صداقة', 'Friendship'),
          'social': s.t('اكتشاف اجتماعي', 'Social discovery'),
        };
        final labels = {
          'books': s.t('القراءة', 'Books'),
          'music': s.t('الموسيقى', 'Music'),
          'travel': s.t('السفر', 'Travel'),
          'cooking': s.t('الطبخ', 'Cooking'),
          'art': s.t('الفن', 'Art'),
          'fitness': s.t('الرياضة', 'Fitness'),
          'nature': s.t('الطبيعة', 'Nature'),
          'games': s.t('الألعاب', 'Games'),
        };
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile['display_name']}، ${profile['age']}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    intentions[profile['intention']] ?? '',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: List<String>.from(profile['interests'] ?? [])
                        .map((i) => Chip(label: Text(labels[i] ?? i)))
                        .toList(),
                  ),
                  if (profile['verified'] == true)
                    Chip(
                      avatar: const Icon(Icons.verified_outlined),
                      label: Text(
                        s.t('تمت مراجعة التوثيق', 'Verification reviewed'),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    s.t(
                      'تظهر الاهتمامات المشتركة كعدد حقيقي، دون نسب توافق مفترضة. يمكنك بدء المحادثة بعد الإعجاب المتبادل.',
                      'Shared interests show an actual count, without invented compatibility percentages. Conversations open after a mutual like.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
