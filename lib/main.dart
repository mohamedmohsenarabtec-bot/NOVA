import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  if (Config.configured) {
    try {
      await Supabase.initialize(
        url: Config.url,
        publishableKey: Config.key,
        debug: false,
      );
    } catch (_) {
      startupError = 'تعذر بدء الاتصال بالخدمة / Could not initialize backend';
    }
  }
  runApp(NovaApp(startupError: startupError));
}
