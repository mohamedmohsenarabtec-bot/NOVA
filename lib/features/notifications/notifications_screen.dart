import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  final NovaRepository repo;
  const NotificationsScreen({super.key, required this.repo});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int offset = 0;
  late Future<DbRow> data = widget.repo.notifications();
  void reload() => setState(() {
    data = widget.repo.notifications(offset: offset);
  });
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AsyncPane<DbRow>(
      future: data,
      retry: reload,
      builder: (inbox) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            s.t('إشعاراتك', 'Your notifications'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(
            s.t(
              'داخل التطبيق • آخر 90 يومًا. إشعارات الهاتف ليست مفعّلة.',
              'In-app • last 90 days. Device push is not enabled.',
            ),
          ),
          TextButton(
            onPressed: () => guarded(context, () async {
              await widget.repo.readNotifications();
              reload();
            }),
            child: Text(s.t('قراءة الكل', 'Mark all read')),
          ),
          if ((inbox['items'] as List).isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                s.t('لا توجد إشعارات الآن.', 'You are all caught up.'),
              ),
            ),
          for (final n in inbox['items'] as List)
            Card(
              child: ListTile(
                leading: Icon(
                  n['read_at'] == null
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none,
                ),
                title: Text(
                  s.t(
                    {
                          'like': 'هناك إعجاب جديد',
                          'match': 'تطابق متبادل جديد',
                          'message': 'لديك رسالة جديدة',
                          'verification': 'تحديث التوثيق',
                          'billing': 'تحديث العضوية',
                          'referral': 'تم منح مكافأة دعوة',
                          'expiring': 'إعجاب مرسل يقترب من انتهاء المهلة',
                        }[n['kind']] ??
                        'تحديث لحسابك',
                    {
                          'like': 'A new like',
                          'match': 'A new mutual match',
                          'message': 'You have a new message',
                          'verification': 'Verification update',
                          'billing': 'Membership update',
                          'referral': 'Referral reward granted',
                          'expiring': 'A pending like is nearing expiration',
                        }[n['kind']] ??
                        'Account update',
                  ),
                ),
                subtitle: Text(n['created_at'].toString().substring(0, 16)),
                onTap: () => guarded(context, () async {
                  await widget.repo.readNotifications(n['id']);
                  if (!context.mounted) return;
                  if (['message', 'match'].contains(n['kind']) &&
                      n['reference_id'] != null) {
                    context.go('/chat/${n['reference_id']}');
                  } else if (n['kind'] == 'like' || n['kind'] == 'expiring') {
                    context.go('/liked');
                  } else if (n['kind'] == 'referral') {
                    context.go('/referrals');
                  } else if (n['kind'] == 'billing') {
                    context.go('/plans');
                  } else if (n['kind'] == 'verification') {
                    context.go('/account');
                  } else {
                    reload();
                  }
                }),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: offset == 0
                    ? null
                    : () {
                        offset -= 30;
                        reload();
                      },
                child: Text(s.t('السابق', 'Previous')),
              ),
              TextButton(
                onPressed: (inbox['items'] as List).length < 30
                    ? null
                    : () {
                        offset += 30;
                        reload();
                      },
                child: Text(s.t('التالي', 'Next')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
