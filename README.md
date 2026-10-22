# NOVA — معاينة تطوير 0.3

تطبيق Flutter قائم بالعربية والإنجليزية، متصل بمشروع Supabase الحقيقي، للويب وAndroid وiOS. **ليس إصدارًا تجاريًا معتمدًا.**

- [افتح التطبيق](https://mohamedmohsenarabtec-bot.github.io/NOVA/)
- [المصدر](https://github.com/mohamedmohsenarabtec-bot/NOVA)
- [نتائج البناء والتحقق والقيود](BUILD_STATUS.md)
- [تعليمات التشغيل والنشر بالعربية](docs/deployment.md)

الإصدار 0.3 يصلح انتظار الشبكة قبل ظهور Flutter ويضيف ملفًا قابلًا للتحرير، وصورًا محفوظة بضوابط ظهور، وفلاتر اكتشاف ومفضلة، وإعجابات معلقة 48 ساعة وتطابقًا ودردشة، وإشعارات داخل التطبيق، وإحالات خادمية. واجهة العضويات تعرض أسعارًا مقترحة فقط؛ لا دفع أو اشتراك أو تجربة مدفوعة تلقائية. اختيار اللغة والمظهر محفوظ، والشعار المتجه الأصلي مشترك بين المنصات.

لا تُعرض هويات أو صور وهمية في اكتشاف المستخدمين الحقيقيين. حسابات التطوير موسومة ومعزولة، وقد يكون الاكتشاف فارغًا حتى ينضم أشخاص حقيقيون متوافقون. حساب المالك وصلاحياته والحسابات والرسائل السابقة محفوظة. كلمات المرور وإعدادات الإدارة ليست جزءًا من هذا المستودع.

## تشغيل محلي

Flutter 3.47.7 / Dart 3.13.5. انسخ config/local.example.json إلى config/local.json المستبعد من Git، واستخدم URL المشروع الأساسي والمفتاح العام فقط.

```text
flutter pub get --enforce-lockfile
flutter run -d chrome --web-port 3000 --dart-define-from-file=config/local.json
```

التسجيل الحقيقي يستخدم Supabase Auth؛ إعداد التطوير الحالي يؤكد البريد مباشرة. لا يوجد Auth محلي وهمي أو تجاوز RLS. استعادة البريد معطلة حتى إعداد SMTP واختبار الروابط.

## تحقق وبناء

```text
dart format .
flutter analyze
flutter test
flutter build web --release --base-href=/NOVA/ --dart-define-from-file=config/local.json
flutter build apk --release --dart-define-from-file=config/local.json
```

اختبارات SQL المعزولة: supabase start ثم supabase test db. **لا تستخدم db reset على مشروع المالك.** اختبار القبول الحي واختيار بذور تطوير معزولة موثقان في دليل النشر. ملفات النتائج العامة لا تحتوي بيانات دخول.

Android APK موجود في build/app/outputs/flutter-apk/app-release.apk، والتوقيع الحالي للتجربة فقط. رابط الإصدار والبصمة ونتيجة التثبيت الفعلية تسجل في BUILD_STATUS. لا يُعد فحص iOS ناجحًا دون دليل من macOS/Xcode؛ حساب Apple والتوقيع لازمان للمتجر.

## وثائق

[البنية](docs/architecture.md)، [قاعدة البيانات](docs/database.md)، [الأمان](docs/security.md)، [الإشعارات](docs/notifications.md)، [الدفع](docs/payments.md)، [الإشراف وتأسيس المدير](docs/moderation.md)، [التغييرات](CHANGELOG.md).

المتبقي: موافقة تجارية، تكامل المتاجر والدفع وPush، فحص محتوى الصور، عامل حذف نهائي مجدول واحتفاظ مراجع، تحقق أجهزة فعلية وiOS وتدقيق أمني مستقل. لا يدعي التطبيق التوثيق الشخصي أو التشفير الطرفي أو الامتثال القانوني التلقائي.
