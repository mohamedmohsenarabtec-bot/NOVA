# التشغيل والإعداد والنشر

هذه نسخة تطوير، وليست منتجًا جاهزًا للنشر العام. يمكن فتح الواجهة دون حسابات خارجية، لكن التسجيل والبيانات يتطلبان Supabase فعليًا.

## على جهازك الحالي

Flutter موجود في `C:\src\flutter\bin` لكنه غير مضاف إلى PATH. من PowerShell داخل المشروع:

```powershell
.\scripts\run.ps1
```

يفتح Chrome على المنفذ 3000. إذا منعت سياسة Windows تشغيل السكربت، استخدم الأمر المباشر:

```powershell
& 'C:\src\flutter\bin\flutter.bat' run -d chrome --web-port 3000
```

للاتصال بالخدمة، انسخ `config/local.example.json` إلى `config/local.json` وأدخل عنوان مشروع Supabase ومفتاحه **العام** فقط. ثم:

```powershell
& 'C:\src\flutter\bin\flutter.bat' run -d chrome --web-port 3000 --dart-define-from-file=config/local.json
```

## إعداد Supabase

1. أنشئ مشروع تطوير جديدًا في حساب Supabase. احتفظ بكلمة مرور قاعدة البيانات خارج المشروع.
2. ثبّت Supabase CLI بالطريقة الرسمية لجهازك. أدوات CLI وDocker غير متاحة حاليًا في PATH على هذا الجهاز.
3. محليًا، بعد تثبيت Docker وتشغيله: `supabase start` ثم `supabase db reset` ثم `supabase test db`. إعادة الضبط تحذف البيانات المحلية؛ لا تستخدمها على الإنتاج.
4. بعد نجاح الاختبارات محليًا، اربط مشروع التطوير: `supabase login` ثم `supabase link --project-ref YOUR_REF` ثم `supabase db push`. تنطبق الملفات الثلاثة داخل migrations بالترتيب. لا تربط إنتاجًا قبل مراجعة التغييرات والنسخ الاحتياطي.
5. في Auth فعّل تأكيد البريد، عطّل التسجيل المجهول، واضبط كلمة المرور إلى 12 حرفًا على الأقل. اضبط SMTP للإرسال الفعلي وحماية CAPTCHA وحدود التسجيل.
6. للويب المحلي: Site URL هو `http://localhost:3000`. أضف روابط العودة المطلوبة لهذا الأصل. للاستضافة أضف عنوان HTTPS الصحيح فقط.
7. للمحمول أضف `com.nova.app.nova://login-callback/` إلى قائمة Redirect URLs. مخطط الرابط مسجل في Android وiOS؛ اختبر التأكيد والاستعادة على أجهزة فعلية. غيّر المعرف المؤقت والمخطط قبل الإطلاق، ويفضل روابط تطبيق موثقة بنطاقك.
8. أنشئ حساب المالك، أكّد البريد، ثم عيّن دوره من SQL Editor حسب `docs/moderation.md`.

التطبيق لا يقرأ `.env` تلقائيًا؛ ملف `.env.example` يوضح أسماء الإعدادات. مصدر إعداد البناء هو JSON عبر `--dart-define-from-file`. ملفات البيئات الحقيقية مستبعدة من Git. لا تستخدم service-role في إعداد Flutter مطلقًا.

## الويب

```powershell
& 'C:\src\flutter\bin\flutter.bat' build web --release --dart-define-from-file=config/production.json
```

ارفع محتويات `build/web` إلى استضافة ملفات ثابتة مع HTTPS. لا تفتح index.html مباشرة من القرص. اختبر مسارات `/#/admin` و`/#/chat/...`، واستعادة كلمة المرور، وسياسة CSP المناسبة لبناء Flutter. بوابة المشرف حاليًا مسار محمي داخل التطبيق نفسه؛ الاستضافة المنفصلة لم تُنفذ.

## Android

للتجربة شغّل محاكيًا أو صِل هاتفًا مع USB debugging، ثم `scripts/run.ps1 -Target android`. ملف APK التجريبي، عند نجاح البناء، في `build/app/outputs/flutter-apk/app-debug.apk`. ليس ملف نشر.

قبل المتجر: اختر applicationId تملكه بدل `com.nova.app.nova`، وحدّث الاسم والأيقونة وروابط العودة، وأنشئ مفتاح توقيع إصدار محفوظًا بأمان خارج Git. قالب Gradle الحالي يستخدم توقيع debug حتى لإعداد release؛ يجب استبداله قبل إصدار المتجر. بعد إعداد التوقيع: `flutter build appbundle --release --dart-define-from-file=config/production.json`. أكمل إفصاحات البيانات والتصنيف العمري وسياسات الحساب/الاشتراكات.

تعطيل Kotlin incremental compilation يعالج مشكلة مراجع cache عبر القرصين C وD في هذه البيئة. يمكن إعادة تقييمه على CI ذي القرص الواحد بعد التحقق.

## iOS

يتطلب Mac مع Xcode وCocoaPods عند الحاجة وحساب Apple Developer. افتح `ios/Runner.xcworkspace` واضبط Bundle ID وTeam والتوقيع. ثم على Mac: `flutter pub get` و`flutter analyze` و`flutter test` و`flutter build ipa --release --dart-define-from-file=config/production.json`. لا يمكن بناء أو التحقق من iOS من Windows الحالي. اختبر Deep links واستعادة الحساب على جهاز حقيقي.

## الاسم والبيئات

`APP_NAME` يغيّر اسم التطبيق داخل Flutter. أسماء المشغّل واسم الويب والأيقونات ومعرفات الحزم ملفات منصة مستقلة وتحتاج إعادة تسمية عند تثبيت العلامة. لا يوجد فحص قانوني لتوفر اسم NOVA أو نطاقه. استخدم مشاريع Supabase مستقلة للتطوير والتجهيز والإنتاج وملفات JSON مستقلة محلية لكل منها.
