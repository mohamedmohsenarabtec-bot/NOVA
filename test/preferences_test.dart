import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova/app/app.dart';
import 'package:nova/core/preferences.dart';
import 'package:nova/core/theme.dart';
import 'package:nova/shared/app_controls.dart';
import 'package:nova/shared/brand.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'locale and theme survive app recreation; System follows platform',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await SharedPreferences.getInstance();
      final prefs = NovaPreferences(store);
      await tester.pumpWidget(NovaApp(preferences: prefs));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('تفعيل المظهر الداكن'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppControls))).brightness,
        Brightness.dark,
      );
      await prefs.setLocale('en');
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(AppControls))),
        TextDirection.ltr,
      );
      await tester.pumpWidget(const SizedBox());
      final restored = NovaPreferences(await SharedPreferences.getInstance());
      await tester.pumpWidget(NovaApp(preferences: restored));
      await tester.pumpAndSettle();
      expect(restored.locale.languageCode, 'en');
      expect(restored.themeMode, ThemeMode.dark);
      expect(find.byTooltip('Switch to light theme'), findsOneWidget);
      await restored.setTheme(ThemeMode.system);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppControls))).brightness,
        Brightness.light,
      );
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppControls))).brightness,
        Brightness.dark,
      );
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      await restored.setLocale('ar');
      await tester.pumpAndSettle();
      expect(find.text('العربية'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(AppControls))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('scheme foregrounds meet normal text contrast in both themes', () {
    for (final brightness in Brightness.values) {
      final c = NovaTheme.create(brightness).colorScheme;
      for (final pair in [
        (c.surface, c.onSurface),
        (c.primary, c.onPrimary),
        (c.primaryContainer, c.onPrimaryContainer),
        (c.surfaceContainerHighest, c.onSurface),
      ]) {
        final a = pair.$1.computeLuminance();
        final b = pair.$2.computeLuminance();
        final ratio = (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
        expect(ratio, greaterThanOrEqualTo(4.5));
      }
    }
  });

  testWidgets(
    'brand and controls fit 320px with enlarged text in both directions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = NovaPreferences(await SharedPreferences.getInstance());
      for (final language in ['ar', 'en']) {
        await prefs.setLocale(language);
        await tester.pumpWidget(NovaApp(preferences: prefs));
        await tester.pumpAndSettle();
        expect(find.byType(NovaLogo), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
