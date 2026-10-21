import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config.dart';
import 'core/preferences.dart';

import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = NovaPreferences(await SharedPreferences.getInstance());
  String? startupError;
  if (Config.configured) {
    try {
      await Supabase.initialize(
        url: Config.url,
        publishableKey: Config.key,
        debug: false,
      );
      final schemaVersion = await Supabase.instance.client.rpc(
        'client_readiness',
      );
      if (schemaVersion != 4) {
        startupError = 'يلزم تحديث قاعدة البيانات قبل التسجيل / Database migrations required before signup';
      }
    } on PostgrestException catch (error) {
      startupError = error.code == 'PGRST202'
          ? 'الاتصال بالمشروع يعمل، لكن يلزم تطبيق ترحيلات NOVA أولًا / Project reachable; apply NOVA database migrations first'
          : 'تعذر التحقق من جاهزية قاعدة البيانات / Could not verify database readiness';
    } catch (_) {
      startupError = 'تعذر بدء الاتصال بالخدمة / Could not initialize backend';
    }
  }
  runApp(NovaApp(startupError: startupError, preferences: preferences));
}
