import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova/app/app.dart';
import 'package:nova/shared/widgets.dart';
import 'package:nova/core/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late NovaPreferences preferences;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = NovaPreferences(await SharedPreferences.getInstance());
  });
  testWidgets('setup state is honest, Arabic RTL switches to English LTR', (
    tester,
  ) async {
    await tester.pumpWidget(NovaApp(preferences: preferences));
    await tester.pumpAndSettle();
    expect(find.text('بداية علاقة لها معنى'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(EmptyState))),
      TextDirection.rtl,
    );
    expect(find.text('العربية'), findsOneWidget);
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckedPopupMenuItem<String>).at(1));
    await tester.pumpAndSettle();
    expect(find.text('A connection with intention'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(EmptyState))),
      TextDirection.ltr,
    );
  });
  testWidgets('setup works on narrow phone and wide desktop', (tester) async {
    for (final width in [360.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(NovaApp(preferences: preferences));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('nullable async results reach empty-profile builder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncPane<String?>(
          future: Future.value(null),
          retry: () {},
          builder: (value) => Text(value ?? 'new profile'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('new profile'), findsOneWidget);
  });
}
