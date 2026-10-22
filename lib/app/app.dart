import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/strings.dart';
import '../core/preferences.dart';
import '../core/theme.dart';
import '../shared/app_controls.dart';
import '../shared/brand.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/auth_feedback.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/password_screen.dart';
import '../features/subscriptions/plans_screen.dart';
import '../features/admin/admin_screen.dart';
import '../shared/repository.dart';
import '../shared/widgets.dart';
import '../shared/account_scope.dart';
import '../features/profiles/profile_editor.dart';
import '../features/discover/filter_screen.dart';
import '../features/connections/connections_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/referrals/referrals_screen.dart';

class NovaApp extends StatefulWidget {
  final String? startupError;
  final NovaPreferences preferences;
  const NovaApp({super.key, this.startupError, required this.preferences});
  @override
  State<NovaApp> createState() => _NovaAppState();
}

class _NovaAppState extends State<NovaApp> {
  late final GoRouter router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home()),
      GoRoute(path: '/admin', builder: (_, _) => home(admin: true)),
      GoRoute(path: '/password', builder: (_, _) => home(password: true)),
      for (final section in [
        'profile/edit',
        'filters',
        'favorites',
        'liked',
        'notifications',
        'referrals',
        'plans',
        'matches',
        'account',
      ])
        GoRoute(
          path: '/$section',
          builder: (_, _) => home(section: section),
        ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => home(chatId: state.pathParameters['id']),
      ),
    ],
  );
  Widget home({
    bool admin = false,
    bool password = false,
    String? chatId,
    String? section,
  }) {
    if (!Config.configured || widget.startupError != null) {
      return Scaffold(
        appBar: AppBar(title: const NovaLogo(), actions: const [AppControls()]),
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
      password: password,
      chatId: chatId,
      section: section,
    );
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PreferencesScope(
    preferences: widget.preferences,
    child: AnimatedBuilder(
      animation: widget.preferences,
      builder: (context, _) => MaterialApp.router(
        title: Config.name,
        debugShowCheckedModeBanner: false,
        locale: widget.preferences.locale,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: NovaTheme.create(Brightness.light),
        darkTheme: NovaTheme.create(Brightness.dark),
        themeMode: widget.preferences.themeMode,
        routerConfig: router,
      ),
    ),
  );
}

class SessionGate extends StatefulWidget {
  final bool admin;
  final bool password;
  final String? chatId;
  final String? section;
  const SessionGate({
    super.key,
    required this.admin,
    this.password = false,
    this.chatId,
    this.section,
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
  int get selectedTab => switch (widget.section) {
    'matches' => 1,
    'plans' => 2,
    'liked' => 3,
    'account' || 'favorites' || 'referrals' => 4,
    _ => tab,
  };
  Widget sectionBody() => switch (widget.section) {
    'liked' => ConnectionsScreen(repo: repo),
    'favorites' => ConnectionsScreen(repo: repo, favorites: true),
    'notifications' => NotificationsScreen(repo: repo),
    'referrals' => ReferralsScreen(repo: repo),
    'plans' => PlansScreen(repo: repo),
    'matches' => ConversationList(repo: repo),
    'account' => SettingsScreen(repo: repo),
    _ => const SizedBox.shrink(),
  };
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
    return AccountScope(
      repo: repo,
      child: Builder(builder: buildSession),
    );
  }

  Widget buildSession(BuildContext context) {
    if (repo.client.auth.currentSession == null || recovery) {
      return AuthScreen(
        repo: repo,
        recovery: recovery,
        onRecovered: () => setState(() => recovery = false),
      );
    }
    if (widget.password) return PasswordScreen(repo: repo);
    if (widget.admin) return AdminScreen(repo: repo);
    if (widget.section == 'profile/edit') return ProfileEditor(repo: repo);
    if (widget.section == 'filters') return FilterScreen(repo: repo);
    return AsyncPane<DbRow?>(
      future: profile!,
      retry: () => setState(refresh),
      builder: (p) {
        if ((p == null || p['onboarding_complete'] != true) &&
            widget.section != 'account') {
          return OnboardingScreen(
            repo: repo,
            initial: p,
            onComplete: () => setState(refresh),
          );
        }
        if (widget.chatId != null) {
          return ChatScreen(repo: repo, conversationId: widget.chatId!);
        }
        final s = Strings.of(context);
        final pages = [
          DiscoverScreen(repo: repo),
          ConversationList(repo: repo),
          PlansScreen(repo: repo),
          ConnectionsScreen(repo: repo),
          SettingsScreen(repo: repo),
        ];
        final destinations = [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: s.discover,
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            label: s.t('دردشة', 'Chats'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            label: s.t('العضوية', 'Plans'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_border),
            label: s.t('أعجبوا بي', 'Liked you'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: s.t('حسابي', 'Account'),
          ),
        ];
        return Scaffold(
          appBar: AppBar(
            title: const NovaLogo(),
            actions: const [AppControls()],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final content = widget.section != null
                  ? sectionBody()
                  : pages[tab];
              if (constraints.maxWidth < 850) return content;
              return Row(
                children: [
                  NavigationRail(
                    selectedIndex: selectedTab,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (value) => context.go(
                      ['/', '/matches', '/plans', '/liked', '/account'][value],
                    ),
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
                  Expanded(child: content),
                ],
              );
            },
          ),
          bottomNavigationBar: MediaQuery.sizeOf(context).width >= 850
              ? null
              : NavigationBar(
                  selectedIndex: selectedTab,
                  onDestinationSelected: (value) => context.go(
                    ['/', '/matches', '/plans', '/liked', '/account'][value],
                  ),
                  destinations: destinations,
                ),
        );
      },
    );
  }
}
