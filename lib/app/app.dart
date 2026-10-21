import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/strings.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/auth_feedback.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/subscriptions/plans_screen.dart';
import '../features/admin/admin_screen.dart';
import '../shared/repository.dart';
import '../shared/widgets.dart';

class NovaApp extends StatefulWidget {
  final String? startupError;
  const NovaApp({super.key, this.startupError});
  @override
  State<NovaApp> createState() => _NovaAppState();
}

class _NovaAppState extends State<NovaApp> {
  Locale locale = const Locale('ar');
  ThemeMode mode = ThemeMode.dark;
  late final GoRouter router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home()),
      GoRoute(path: '/admin', builder: (_, _) => home(admin: true)),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => home(chatId: state.pathParameters['id']),
      ),
    ],
  );
  Widget home({bool admin = false, String? chatId}) {
    if (!Config.configured || widget.startupError != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(Config.name),
          actions: [languageButton()],
        ),
        body: Builder(
          builder: (context) => EmptyState(
            icon: Icons.settings_input_component,
            title: Strings.of(context)
                .t('بداية علاقة لها معنى', 'A connection with intention'),
            body:
                widget.startupError ??
                Strings.of(context).t(
                  'التطبيق جاهز للإعداد. أضف عنوان Supabase والمفتاح العام وفق دليل README لتفعيل التسجيل والاكتشاف. لا توجد بيانات تجريبية أو حسابات وهمية.',
                  'Backend setup required. Add the Supabase URL and publishable key following README to enable sign-in and discovery. No demo accounts or simulated data.',
                ),
          ),
        ),
      );
    }
    return SessionGate(
      admin: admin,
      chatId: chatId,
      languageButton: languageButton(),
      toggleTheme: () => setState(
        () => mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
      ),
    );
  }

  Widget languageButton() => TextButton(
    onPressed: () => setState(
      () => locale = Locale(locale.languageCode == 'ar' ? 'en' : 'ar'),
    ),
    child: Text(locale.languageCode == 'ar' ? 'English' : 'العربية'),
  );
  ThemeData theme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9D8CFF),
      brightness: brightness,
      primary: brightness == Brightness.dark
          ? const Color(0xFFFF9B91)
          : const Color(0xFF99463F),
      secondary: const Color(0xFF9D8CFF),
      surface: brightness == Brightness.dark
          ? const Color(0xFF11172B)
          : const Color(0xFFF8F7FC),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF090E20)
          : const Color(0xFFF8F7FC),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: Config.name,
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: theme(Brightness.light),
    darkTheme: theme(Brightness.dark),
    themeMode: mode,
    routerConfig: router,
  );
}

class SessionGate extends StatefulWidget {
  final bool admin;
  final String? chatId;
  final Widget languageButton;
  final VoidCallback toggleTheme;
  const SessionGate({
    super.key,
    required this.admin,
    this.chatId,
    required this.languageButton,
    required this.toggleTheme,
  });
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final repo = NovaRepository(Supabase.instance.client);
  StreamSubscription<AuthState>? subscription;
  Future<DbRow?>? profile;
  bool recovery = false;
  int tab = 0;
  @override
  void initState() {
    super.initState();
    refresh();
    subscription = repo.client.auth.onAuthStateChange.listen(
      (state) {
        if (mounted) {
          setState(() {
            recovery =
                state.event == AuthChangeEvent.passwordRecovery ||
                (recovery && state.event != AuthChangeEvent.signedOut);
            refresh();
          });
        }
      },
      onError: (Object error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authFeedback(Strings.of(context), error))),
          );
        }
      },
    );
  }

  void refresh() {
    profile = repo.client.auth.currentSession == null ? null : repo.profile();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (repo.client.auth.currentSession == null || recovery) {
      return AuthScreen(
        repo: repo,
        recovery: recovery,
        onRecovered: () => setState(() => recovery = false),
        languageButton: widget.languageButton,
      );
    }
    return AsyncPane<DbRow?>(
      future: profile!,
      retry: () => setState(refresh),
      builder: (p) {
        if (p == null || p['onboarding_complete'] != true) {
          return OnboardingScreen(
            repo: repo,
            initial: p,
            onComplete: () => setState(refresh),
          );
        }
        if (widget.admin) return AdminScreen(repo: repo);
        if (widget.chatId != null) {
          return ChatScreen(repo: repo, conversationId: widget.chatId!);
        }
        final s = Strings.of(context);
        final pages = [
          DiscoverScreen(repo: repo),
          ConversationList(repo: repo),
          PlansScreen(repo: repo),
          SettingsScreen(repo: repo, toggleTheme: widget.toggleTheme),
        ];
        final destinations = [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: s.discover,
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            label: s.chats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            label: s.plans,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: s.settings,
          ),
        ];
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              Config.name,
              style: TextStyle(letterSpacing: 5, fontWeight: FontWeight.w800),
            ),
            actions: [widget.languageButton],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 850) return pages[tab];
              return Row(
                children: [
                  NavigationRail(
                    selectedIndex: tab,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (value) =>
                        setState(() => tab = value),
                    destinations: destinations
                        .map(
                          (d) => NavigationRailDestination(
                            icon: d.icon,
                            label: Text(d.label),
                          ),
                        )
                        .toList(),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: pages[tab]),
                ],
              );
            },
          ),
          bottomNavigationBar: MediaQuery.sizeOf(context).width >= 850
              ? null
              : NavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: (value) => setState(() => tab = value),
                  destinations: destinations,
                ),
        );
      },
    );
  }
}
