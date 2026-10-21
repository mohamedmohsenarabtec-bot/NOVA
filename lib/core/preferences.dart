import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device preferences only. Authentication and roles stay in Supabase.
class NovaPreferences extends ChangeNotifier {
  final SharedPreferences store;
  late Locale locale;
  late ThemeMode themeMode;
  bool saveFailed = false;
  Future<void> _pending = Future.value();

  NovaPreferences(this.store) {
    locale = Locale(store.getString('nova.locale') == 'en' ? 'en' : 'ar');
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == store.getString('nova.theme'),
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setLocale(String value) {
    if (!['ar', 'en'].contains(value)) throw ArgumentError.value(value);
    locale = Locale(value);
    notifyListeners();
    return _save('nova.locale', value);
  }

  Future<void> setTheme(ThemeMode value) {
    themeMode = value;
    notifyListeners();
    return _save('nova.theme', value.name);
  }

  Future<void> _save(String key, String value) {
    _pending = _pending.then((_) async {
      try {
        saveFailed = !await store.setString(key, value);
      } catch (_) {
        saveFailed = true;
      }
      notifyListeners();
    });
    return _pending;
  }
}

class PreferencesScope extends InheritedNotifier<NovaPreferences> {
  const PreferencesScope({
    super.key,
    required NovaPreferences preferences,
    required super.child,
  }) : super(notifier: preferences);

  static NovaPreferences of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreferencesScope>()!.notifier!;
}
