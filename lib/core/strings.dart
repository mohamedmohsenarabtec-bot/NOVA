import 'package:flutter/material.dart';

class Strings {
  final bool ar;
  const Strings(this.ar);
  static Strings of(BuildContext context) =>
      Strings(Localizations.localeOf(context).languageCode == 'ar');
  String t(String arabic, String english) => ar ? arabic : english;
  String get discover => t('اكتشف', 'Discover');
  String get chats => t('المحادثات', 'Conversations');
  String get settings => t('حسابي', 'My account');
  String get plans => t('العضويات', 'Memberships');
  String get retry => t('إعادة المحاولة', 'Retry');
  String get error => t(
    'تعذر تنفيذ الطلب. تحقق من الاتصال والإعدادات ثم حاول مجددًا.',
    'Request failed. Check connection and configuration, then retry.',
  );
}
