import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/strings.dart';

class AsyncPane<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T) builder;
  final VoidCallback retry;
  final Widget? loading;
  const AsyncPane({
    super.key,
    required this.future,
    required this.builder,
    required this.retry,
    this.loading,
  });
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(Strings.of(context).error),
              ),
              FilledButton(
                onPressed: retry,
                child: Text(Strings.of(context).retry),
              ),
            ],
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return loading ?? const Center(child: CircularProgressIndicator());
      }
      return builder(snapshot.data as T);
    },
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

Future<void> guarded(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(operationFeedback(Strings.of(context), error))),
      );
    }
  }
}

String operationFeedback(Strings s, Object error) {
  final message = error is PostgrestException
      ? error.message
      : error is StateError
      ? error.message.toString()
      : '';
  if (error is PostgrestException && error.code == '23505') {
    return s.t(
      'القيمة مستخدمة بالفعل؛ اختر قيمة مختلفة.',
      'This value is already in use; choose another.',
    );
  }
  return switch (message) {
    'Image exceeds 5MB' => s.t(
      'اختر صورة أصغر من 5 ميغابايت.',
      'Choose an image smaller than 5MB.',
    ),
    'JPEG, PNG or WebP required' || 'Invalid image' => s.t(
      'اختر صورة JPEG أو PNG أو WebP سليمة.',
      'Choose a valid JPEG, PNG or WebP image.',
    ),
    'Image dimensions too large' => s.t(
      'أبعاد الصورة كبيرة جدًا؛ اختر نسخة أصغر من 24 ميغابكسل.',
      'Image dimensions exceed 24 megapixels; choose a smaller version.',
    ),
    'Daily limit reached' => s.t(
      'وصلت لحد الإعجابات اليومي. حاول غدًا.',
      'Daily like allowance reached. Try tomorrow.',
    ),
    'Advanced filters require Plus' => s.t(
      'هذه الفلاتر تتطلب استحقاق Plus أو Premium صالحًا.',
      'These filters require an active Plus or Premium entitlement.',
    ),
    'Invalid invitation' ||
    'Invitation already claimed' ||
    'Invitation eligibility unavailable' => s.t(
      'الرمز غير صالح لهذا الحساب أو استُخدم بالفعل؛ تُقبل دعوة واحدة خلال أول 7 أيام.',
      'This invitation is unavailable or already claimed; one invitation is allowed within your first 7 days.',
    ),
    'Adults 18+ only' => s.t(
      'يجب أن يكون تاريخ الميلاد صحيحًا والعمر 18 عامًا على الأقل.',
      'Use a valid birth date; you must be at least 18.',
    ),
    'Conversation unavailable' ||
    'Profile unavailable' ||
    'Unavailable profile' => s.t(
      'لم يعد هذا التواصل متاحًا وفق إعدادات الخصوصية والسلامة.',
      'This connection is no longer available under privacy and safety rules.',
    ),
    'Cancellation period ended' => s.t(
      'انتهت مهلة الإلغاء؛ تواصل مع الدعم.',
      'The cancellation period ended; contact support.',
    ),
    _ => s.error,
  };
}
