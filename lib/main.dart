import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config.dart';
import 'core/preferences.dart';
import 'core/theme.dart';
import 'shared/brand.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NovaBootstrap());
}

/// Draw first; never leave a native splash waiting on an unbounded network call.
class NovaBootstrap extends StatefulWidget {
  final Future<NovaPreferences> Function()? loader;
  const NovaBootstrap({super.key, this.loader});
  @override
  State<NovaBootstrap> createState() => _NovaBootstrapState();
}

class _NovaBootstrapState extends State<NovaBootstrap> {
  Future<void>? backend;
  String startupStage = 'preferences';
  late Future<NovaPreferences> startup = load();
  Future<NovaPreferences> load() => (widget.loader?.call() ?? initialize())
      .timeout(const Duration(seconds: 26))
      .catchError((Object error, StackTrace trace) {
        // Never log exception messages, URLs, sessions or credentials.
        debugPrint('NOVA startup: $startupStage / ${error.runtimeType}');
        Error.throwWithStackTrace(error, trace);
      });
  Future<NovaPreferences> initialize() async {
    final preferences = NovaPreferences(
      await SharedPreferences.getInstance().timeout(const Duration(seconds: 6)),
    );
    if (!Config.configured) return preferences;
    startupStage = 'backend';
    backend ??=
        Supabase.initialize(
          url: Config.url,
          publishableKey: Config.key,
          debug: false,
        ).then<void>((_) {}).catchError((Object error) {
          backend = null;
          throw error;
        });
    await backend!.timeout(const Duration(seconds: 12));
    startupStage = 'capabilities';
    final version = await Supabase.instance.client
        .rpc('client_capabilities')
        .timeout(const Duration(seconds: 12));
    if (version is! int || version < 10) throw StateError('Schema unavailable');
    return preferences;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<NovaPreferences>(
    future: startup,
    builder: (context, state) {
      if (state.hasData) return NovaApp(preferences: state.data!);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: NovaTheme.create(Brightness.light),
        darkTheme: NovaTheme.create(Brightness.dark),
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const NovaLogo(size: 64),
                    const SizedBox(height: 32),
                    if (!state.hasError) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      const Text('جارٍ الاتصال بأمان… / Connecting securely…'),
                    ] else ...[
                      const Text(
                        'تعذّر الاتصال. تحقق من الإنترنت ثم أعد المحاولة.\nCould not connect. Check your connection and retry.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => setState(() {
                          startup = load();
                        }),
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة / Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
