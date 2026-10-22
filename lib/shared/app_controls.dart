import 'package:flutter/material.dart';

import 'dart:async';

import 'package:go_router/go_router.dart';

import 'account_scope.dart';
import 'repository.dart';

import '../core/preferences.dart';
import '../core/strings.dart';

/// One locale and appearance control shared by every application header.
class AppControls extends StatelessWidget {
  const AppControls({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = PreferencesScope.of(context);
    final s = Strings.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final compact =
        MediaQuery.sizeOf(context).width < 480 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final themeLabel = s.t('المظهر', 'Appearance');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (AccountScope.maybeOf(context)?.client.auth.currentUser != null)
          NotificationBell(repo: AccountScope.maybeOf(context)!),
        PopupMenuButton<String>(
          tooltip: s.t('اللغة', 'Language'),
          initialValue: prefs.locale.languageCode,
          onSelected: prefs.setLocale,
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: 'ar',
              checked: s.ar,
              child: const Text('العربية'),
            ),
            CheckedPopupMenuItem(
              value: 'en',
              checked: !s.ar,
              child: const Text('English'),
            ),
          ],
          child: Semantics(
            button: true,
            label: s.t('اللغة: العربية', 'Language: English'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Text(
                compact
                    ? (s.ar ? 'عربي' : 'EN')
                    : (s.ar ? 'العربية' : 'English'),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: s.t(
            dark ? 'تفعيل المظهر الفاتح' : 'تفعيل المظهر الداكن',
            dark ? 'Switch to light theme' : 'Switch to dark theme',
          ),
          onPressed: () =>
              prefs.setTheme(dark ? ThemeMode.light : ThemeMode.dark),
          icon: Icon(
            dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          ),
        ),
        PopupMenuButton<ThemeMode>(
          tooltip: themeLabel,
          icon: const Icon(Icons.more_vert),
          initialValue: prefs.themeMode,
          onSelected: prefs.setTheme,
          itemBuilder: (_) => [
            for (final mode in ThemeMode.values)
              CheckedPopupMenuItem(
                value: mode,
                checked: mode == prefs.themeMode,
                child: Text(
                  s.t(
                    switch (mode) {
                      ThemeMode.system => 'النظام',
                      ThemeMode.light => 'فاتح',
                      ThemeMode.dark => 'داكن',
                    },
                    switch (mode) {
                      ThemeMode.system => 'System',
                      ThemeMode.light => 'Light',
                      ThemeMode.dark => 'Dark',
                    },
                  ),
                ),
              ),
          ],
        ),
        if (prefs.saveFailed)
          Tooltip(
            message: s.t(
              'تعذر حفظ التفضيلات على الجهاز',
              'Could not save device preferences',
            ),
            child: const Icon(Icons.warning_amber_outlined),
          ),
      ],
    );
  }
}

class NotificationBell extends StatefulWidget {
  final NovaRepository repo;
  const NotificationBell({super.key, required this.repo});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int unread = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 40), (_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final inbox = await widget.repo.notifications();
      if (mounted) setState(() => unread = (inbox['unread'] as num).toInt());
    } catch (_) {
      /* The full inbox offers explicit retry; do not expose diagnostics. */
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return IconButton(
      tooltip: s.t(
        'الإشعارات، غير المقروء $unread',
        'Notifications, $unread unread',
      ),
      onPressed: () => context.go('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
