# تشغيل NOVA المحدث — الإصدار 0.2

هذه الإضافة هي الحالة الأحدث؛ التعليمات السابقة أدناه مرجع تاريخي عند اختلاف الحالة.

نتيجة التحقق: نجح تنسيق المشروع وتحليله و26 اختبار Flutter وبناء الويب وAPK release. نجح سير CI رقم 39629020838، بما فيه 31 اختبار قاعدة بيانات. نشر Pages رقم 39629020501 اكتمل للمصدر dfc4137، واختُبر الموقع بمتصفح Chrome حقيقي للتبديل بين اللغتين والمظهر وحفظهما والدخول والدردشة واستعادتها، كما اختُبرت بوابة المالك وشاشة تغيير كلمة المرور. نُزل APK المنشور وطابقت بصمته البناء المحلي. الأدلة الخالية من بيانات الدخول في docs/verification/iteration-0.2.json.

حالة iOS: غير مكتمل؛ سير macOS رقم 39629020519 ما زال في انتظار مشغّل، ولم يُبن تطبيق iOS موقّع أو يُختبر جهاز حقيقي.

- التطبيق: https://mohamedmohsenarabtec-bot.github.io/NOVA/
- المصدر: https://github.com/mohamedmohsenarabtec-bot/NOVA
- اللغة في الرأس تعرض الاختيار الحالي: العربية/English، أو عربي/EN على الهاتف. من القائمة اختر اللغة الأخرى. يتبدل اتجاه الواجهة فورًا ويُحفظ الاختيار على الجهاز.
- الشمس تظهر في الوضع الفاتح والقمر في الداكن. اضغط الأيقونة للتبديل؛ قائمة المظهر المجاورة توفر «النظام» لمتابعة إعداد الجهاز. اللغة والمظهر مشتركان بين جميع الشاشات ويحفظان بعد الإغلاق.
- حسابا التطوير أُنشئا فعلًا، وبقيا مستخدمين عاديين. بيانات دخولهما هي ما اتفق عليه المالك في المحادثة الخاصة؛ لا توضع في الوثائق العامة أو المصدر أو إعدادات البناء. ملفا الحسابين مختلفان، وبينهما تطابق ودردشة محفوظة. اختبار الحظر أُلغي بعد التحقق حتى تظل الدردشة قابلة للاستخدام.
- بناءً على طلب المالك أُنشئ حسابه الدائم من خلال Auth العادي، وتحققت هويته بمعرف UUID قبل منح administrator من جلسة قاعدة بيانات مخوّلة. بيانات الدخول العشوائية في `.local/owner-access.json` على جهاز المالك فقط، مستبعدة من Git. لا ترسل محتوى الملف في المحادثة أو ترفعه إلى المستودع.
- افتح التطبيق واختر «تسجيل الدخول» باستخدام بيانات الملف المحلي. لتغيير كلمة المرور افتح `https://mohamedmohsenarabtec-bot.github.io/NOVA/#/password`، ثم أدخل الحالية والجديدة وتأكيدها؛ يجب أن تكون الجديدة 12 حرفًا على الأقل. بعد نجاح التغيير احذف الملف المحلي بنفسك. لا يحتاج ذلك إلى إرسال بريد.
- بوابة الإدارة: `https://mohamedmohsenarabtec-bot.github.io/NOVA/#/admin`. يستطيع المدير الدخول إليها قبل إكمال ملف التعارف. ملف المالك مخفي افتراضيًا حتى يختار تفضيلاته بنفسه. الإشراف الحالي محدود بمراجعة البلاغات وإغلاقها أو تعليق الحسابات.

لأي تثبيت مستقل، أنشئ حساب المالك عبر التسجيل العادي ثم تحقق من هويته خارج التطبيق وافحص صف Auth الدقيق. يتطلب `supabase/bootstrap_admin.sql` جلسة postgres/supabase_admin، ومعرف Auth UUID مراجعًا في `nova.owner_uuid`. يُنفذ داخل معاملة واحدة، ويرفض وجود مدير آخر، ويسجل العملية في سجل التدقيق. مثال تشغيلي: جهّز ملفًا محليًا مستبعدًا من Git بنسخة السكربت مع `set local nova.owner_uuid = 'REVIEWED_AUTH_UUID';` مباشرة بعد `begin;`، ثم مرره إلى `supabase db query --linked --file`. لا تستخدم بريدًا قدمه العميل وحده، ولا تنشئ RPC عامًا لتعيين الأدوار.

إعادة توليد الشعار والأيقونات: `flutter test tool/generate_brand.dart`. ملفات SVG في `assets/brand/`، والرسم المستخدم داخل Flutter في `lib/shared/brand.dart`، وأصول Android تحت `android/app/src/main/res/`، وأصول iOS تحت `ios/Runner/Assets.xcassets/`، وأصول الويب تحت `web/`.

اختبار الحسابات القائمة دون تعديل كلمات مرورها: مرّر عناوينها الخاصة إلى `scripts/verify_development.dart` مع config/local.json. كلمة المرور تدخل بمتغير عملية مؤقت `NOVA_DEVELOPMENT_PASSWORD` ويُحذف فور انتهاء العملية؛ لا تكتبها في ملف تشغيل محفوظ أو سطر أوامر متشارك. الأداة لا تعيد تعيين الحسابات أو تحذفها. اختبار الإنشاء الافتراضي `scripts/live_smoke.dart` يحذف فقط الحسابات الجديدة التي ينشئها؛ خيار `--retain-development-accounts` يحتفظ بحسابات التطوير ويتطلب كلمة مرور خاصة من البيئة المؤقتة أو إدخال مخفي، ولا يقبل منحها دور موظف.

بناء الويب: `flutter build web --release --base-href=/NOVA/ --dart-define-from-file=config/local.json`.
بناء Android: `flutter build apk --release --dart-define-from-file=config/local.json`؛ الملف `build/app/outputs/flutter-apk/app-release.apk`. توقيعه الحالي تجريبي، ويلزم إعداد توقيع إصدار خاص قبل Google Play. التنزيل من GitHub Releases: https://github.com/mohamedmohsenarabtec-bot/NOVA/releases/download/v0.2.0-preview.2/app-release.apk .

أضيف سير عمل `.github/workflows/ios.yml` للبناء على macOS دون توقيع. نجاحه، إن اكتمل، يثبت البناء فقط؛ لا يثبت تشغيل جهاز حقيقي أو إصدار App Store. ما يزال النشر على App Store يتطلب حساب Apple وشهادات وتوفيرًا وإعداد المتجر.

---

# الإعداد والنشر — مشروع NOVA الموجود

لا تنشئ مشروع Supabase جديدًا، ولا تستخدم reset أو أوامر إسقاط الجداول على مشروع المالك. ملفات الحسابات والإعدادات المحلية والأدوات المحمولة مستبعدة من Git.

## ما تم التحقق منه

المشروع `zywftgogopjdqjdceqzd` يستجيب لطلبات Auth بالمفتاح العام. التسجيل بالبريد مفعّل وتأكيد البريد معطّل فعلًا. لم يُغير هذا التنفيذ إعدادًا أمنيًا بعيدًا. آخر حالة فحص الجاهزية في `docs/verification/backend-connection.json`؛ طُبّقت الترحيلات الأربعة بعد فحص المخطط الفارغ وتأكد أن client_readiness يرجع الإصدار 4 فعليًا.

## تفويض إدارة Supabase دون إرسال أسرار

في VS Code اختر Terminal ثم New Terminal داخل مجلد NOVA وشغّل:

```powershell
.\.tools\supabase\supabase.exe --agent no --output-format text login
```

اضغط Enter لفتح المتصفح. سجّل الدخول إلى حساب المشروع، ثم انسخ رمز التحقق من الموقع إلى الطرفية نفسها. لا ترسله في المحادثة. الأمر الرسمي يحفظ جلسة CLI خارج المستودع. يمكن بدل ذلك ربط إضافة Supabase وتفويض المشروع منها. لا نحتاج كلمة مرور قاعدة البيانات أو service-role أو رمز وصول خاص في المحادثة.

بعد التفويض تحقق:

```powershell
.\.tools\supabase\supabase.exe projects list
```

ثم افحص مخطط المشروع قراءة فقط:

```powershell
.\.tools\supabase\supabase.exe db query --linked --project-ref zywftgogopjdqjdceqzd --file supabase/inspect_remote.sql
```

CLI الحالي يدعم الاستعلام عبر Management API. نتائج الفحص لا تتضمن كلمات مرور أو نصوص رسائل. إذا وجدت جداول متعارضة أو مخططًا غير معروف، لا تطبّق الترحيلات فوقه. افحص تاريخ الترحيلات والمخطط والبيانات دون حذفها. جدول profiles الغائب في API لا يثبت أن بقية القاعدة فارغة.

إذا أثبت الفحص أن قاعدة التطبيق جديدة ولا توجد تعارضات، اربط المشروع الموجود، ثم استخدم dry run قبل التطبيق:

```powershell
.\.tools\supabase\supabase.exe link --project-ref zywftgogopjdqjdceqzd
.\.tools\supabase\supabase.exe db push --dry-run --skip-vault
.\.tools\supabase\supabase.exe db push --skip-vault
.\.tools\supabase\supabase.exe db query --linked --project-ref zywftgogopjdqjdceqzd --file supabase/verify_remote.sql
```

إذا طلبت الأداة كلمة مرور قاعدة، لا ترسلها في المحادثة. توقّف واستخدم اتصال Supabase المفوض أو مسار Management API المدعوم بدلًا من طلب أسرار. لا تُعدّل سجل الترحيلات أو تُعلّم ملفات مطبقة دون دليل تنفيذ.

## تجربة التسجيل دون شراء SMTP

المسار الحالي في لوحة Supabase: **Authentication → Sign In / Providers → Email → Confirm email**. في مشروع التطوير فقط اترك Confirm email معطّلًا. الفحص الحالي يؤكد أنه معطّل بالفعل، فلا تغيّر شيئًا دون حاجة. تشرح [وثائق Supabase الرسمية](https://supabase.com/docs/guides/auth/general-configuration) أن هذا الإعداد يؤكد البريد ضمنيًا عند إنشاء الحساب؛ لذلك لا نزيل شرط الحساب المؤكد من سياسات الخادم.

لا تعطّل CAPTCHA أو حدود التسجيل تلقائيًا. إذا ظهر تحدي أمني فإكمال تكامله مطلوب بدل تجاوزه. لا تفعّل التسجيل المجهول. الإعداد المحلي `supabase/config.toml` يخص البيئة المحلية؛ لا يُغيّر إعداد المشروع المستضاف من تلقاء نفسه.

استعادة كلمة المرور ليست جزءًا من رحلة الاختبار الأساسية ولا تعد بإرسال بريد. تفعيلها لاحقًا يحتاج إرسالًا فعليًا وروابط عودة مختبرة. قبل إطلاق الجمهور أعد تقييم تأكيد البريد، وفعّل سياسة 12 حرفًا أو أكثر من إعداد Auth، وراجع SMTP والحماية.

## تشغيل الويب المحلي

`config/local.json` أُنشئ من البيانات العامة المقدمة. التطبيق يستخدم `--dart-define-from-file` ولا يقرأ .env تلقائيًا:

```powershell
.\scripts\run.ps1
```

الواجهة على المنفذ 3000. الروابط تستخدم hash، مثل `/#/admin` و`/#/chat/...`، لذلك تعمل إعادة تحميل المسار على استضافة ثابتة. لا تفتح build/web/index.html مباشرة من القرص.

## GitHub وGitHub Pages

ثُبتت أداة GitHub الرسمية محليًا في `.tools/github/bin/gh.exe`. سجّل المالك الدخول بنجاح إلى `mohamedmohsenarabtec-bot`. أُنشئ المستودع خاصًا ثم أصبح عامًا بموافقة المالك الصريحة لتفعيل Pages على خطته الحالية. المستودع الذي رُفع إليه المصدر هو:

https://github.com/mohamedmohsenarabtec-bot/NOVA

لإعادة التفويض عند الحاجة، استخدم الأمر الرسمي في الطرفية:

```powershell
.\.tools\github\bin\gh.exe auth login
.\.tools\github\bin\gh.exe auth status
```

لا ترسل كلمة مرور أو personal access token. رمز ربط الجهاز مؤقت وليس كلمة مرور GitHub. توثيق الأداة: https://cli.github.com/manual/gh_auth_login .

Workflow النشر هو `.github/workflows/pages.yml`: تثبيت Flutter المتوافق، فحص التنسيق والتحليل والاختبارات، إنشاء إعداد عام من Actions variables، بناء release بالمسار الذي تعيده configure-pages، ثم upload-pages-artifact وdeploy-pages بصلاحيات النشر اللازمة فقط.

داخل المستودع: **Settings → Secrets and variables → Actions → Variables**. المتغيرات المطلوبة هي `SUPABASE_URL` و`SUPABASE_PUBLISHABLE_KEY`، و`APP_NAME` اختياري. يجب أن يحتوي المفتاح على publishable أو anon فقط، وليس service-role. يُرفض المفتاح الخاص قبل البناء ولا تُطبع قيمته. يمكن للأداة ضبط المتغيرات تلقائيًا من ملف المالك المحلي بعد التفويض.

في **Settings → Pages → Build and deployment → Source** اختر **GitHub Actions**، أو استخدم API المفوض إذا كان الحساب يدعم ذلك. المستودع الخاص يحتاج خطة GitHub تدعم Pages الخاصة. إذا رفض GitHub ذلك، لا تحوّل المستودع إلى عام تلقائيًا: يلزم اختيار المالك بعد توضيح أن المصدر سيصبح عامًا. [متطلبات Pages الرسمية](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

نجح workflow النشر واستُرجع رابط التطبيق الفعلي من GitHub وتأكد HTTP 200: https://mohamedmohsenarabtec-bot.github.io/NOVA/ . مرجع النشر والاختبار في docs/verification/pages.json. عنوان المستودع يعرض المصدر، وليس التطبيق. GitHub Pages يستضيف عميل Flutter الثابت؛ Supabase يظل مسؤولًا عن Auth وقاعدة البيانات والصلاحيات.

بعد نجاح النشر اضبط Supabase Site URL على أصل ومعرّف مسار Pages الفعلي، وأضف رابط العودة المطلوب بدقة. للويب المحلي استخدم http://localhost:3000. استعادة البريد غير مفعلة هنا. لا نحتاج روابط بريد لتجربة التسجيل الفوري.

## الاختبارات الحية

فحص الاتصال الآمن:

```powershell
& 'C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe' run scripts/check_backend.dart config/local.json
```

بعد الترحيل وباستخدام عنوانين جديدين يملكهما المالك:

```text
dart run scripts/live_smoke.dart config/local.json OWNER_EMAIL+nova1@example.com OWNER_EMAIL+nova2@example.com --verify-moderation
```

العناوين السابقة أمثلة فقط؛ لا تُستخدم بدل عناوين المالك. يولّد السكربت كلمات مرور في الذاكرة، ويختبر الحسابين والصلاحيات، ويستخدم جلسة CLI لتعيين وإلغاء دور moderator لحساب الاختبار فقط عند طلب ذلك. يحذف فقط الحسابات التي أنشأها هذا التشغيل في finally. لا يغير الحسابات الموجودة أو يحاول إعادة تعيين كلمات مرورها. النتائج محلية في `.local/live-results.json` دون كلمات مرور أو رموز جلسات. نجح اختبار Realtime الفعلي. لإضافة فحص المتصفح استخدم --browser-url=https://mohamedmohsenarabtec-bot.github.io/NOVA/؛ هذا المسار نُفّذ في Chrome ونجح في تسجيل الدخول وإعادة تحميل المحادثة واستعادة الجلسة والرسائل. التحقق يجمع استجابة الرسائل الحقيقية وعناصر الواجهة وصورًا محلية للمراجعة، دون تسجيل كلمات مرور أو رموز جلسات.

لـpgTAP استخدم `supabase test db` على بيئة محلية معزولة أو وظيفة CI database، وليس reset على المشروع البعيد. هذه الاختبارات داخل transaction وتتراجع في النهاية. أي اختبار غير منفذ يسجل NOT TESTED.

## Android وiOS

للتجربة: `scripts/run.ps1 -Target android`. بناء debug:

```powershell
& 'C:\src\flutter\bin\flutter.bat' build apk --debug --dart-define-from-file=config/local.json
```

الملف في `build/app/outputs/flutter-apk/app-debug.apk` وليس إصدار متجر. قبل الإطلاق اختر معرف حزمة واسمًا وأيقونة تملكها واضبط release signing؛ إعداد Gradle الحالي يستخدم توقيع debug حتى لإعداد release. لا ترفعه للمتجر بهذا التوقيع.

iOS يتطلب Mac وXcode وحساب Apple Developer وضبط Team/Bundle ID والتوقيع، ثم flutter build ipa. لا يمكن اختباره من Windows الحالي. الصور والصوت وFCM والدفع ما زالت غير مكتملة، ولا يُعد نجاح نشر الويب إثباتًا لجهوزية تجارية.
