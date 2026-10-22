import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as image;
import 'package:nova/main.dart';
import 'package:nova/core/preferences.dart';
import 'package:nova/core/photo_processing.dart';
import 'package:nova/core/strings.dart';
import 'package:nova/shared/widgets.dart';
import 'package:nova/features/profiles/profile_fields.dart';
import 'package:nova/features/settings/settings_screen.dart';

import 'features_test.dart' show TestRepository;

class StaffRepository extends TestRepository {
  @override
  Future<List<Map<String, dynamic>>> roles() async => [
    {'role': 'moderator'},
  ];
}

void main() {
  late TestRepository ordinary;
  late StaffRepository staff;
  setUp(() {
    ordinary = TestRepository();
    staff = StaffRepository();
  });
  tearDown(() async {
    await ordinary.client.dispose();
    await staff.client.dispose();
  });
  testWidgets(
    'first frame is rendered and stalled startup offers Retry, then recovers',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = NovaPreferences(await SharedPreferences.getInstance());
      var attempt = 0;
      await tester.pumpWidget(
        NovaBootstrap(
          loader: () {
            attempt++;
            return attempt == 1
                ? Completer<NovaPreferences>().future
                : Future.value(prefs);
          },
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 27));
      await tester.pump();
      expect(find.text('إعادة المحاولة / Retry'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة / Retry'));
      await tester.pumpAndSettle();
      expect(attempt, 2);
      expect(find.text('بداية علاقة لها معنى'), findsOneWidget);
    },
  );
  test(
    'profile completion is bounded and optional fields can remain empty',
    () {
      expect(ProfileFields.completion({}), 0);
      expect(
        ProfileFields.completion({
          'display_name': 'A name',
          'onboarding_complete': true,
        }),
        40,
      );
      expect(ProfileFields.validateName(' '), isNotNull);
      expect(ProfileFields.validateName('A name'), isNull);
    },
  );
  test('Arabic and English comma lists are trimmed and deduplicated', () {
    expect(ProfileFields.values('قراءة، music, قراءة, '), ['قراءة', 'music']);
  });
  test('image processing decodes bytes, resizes and emits clean JPEG', () {
    final source = image.Image(width: 1800, height: 900);
    image.fill(source, color: image.ColorRgb8(90, 70, 150));
    final result = processProfilePhoto(
      Uint8List.fromList(image.encodePng(source)),
    );
    expect(result.take(2), [255, 216]);
    final decoded = image.decodeJpg(result)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 800);
    expect(decoded.exif.isEmpty, isTrue);
  });
  test('image processing rejects disguised non-images and oversized files', () {
    expect(
      () => processProfilePhoto(
        Uint8List.fromList('<svg>not an image</svg>'.codeUnits),
      ),
      throwsStateError,
    );
    expect(() => processProfilePhoto(Uint8List(5242881)), throwsStateError);
  });
  test(
    'operation feedback describes a real failure without exposing diagnostics',
    () {
      expect(
        operationFeedback(
          const Strings(false),
          StateError('Image exceeds 5MB'),
        ),
        contains('5MB'),
      );
      expect(
        operationFeedback(
          const Strings(false),
          StateError('private diagnostic'),
        ),
        isNot(contains('private diagnostic')),
      );
    },
  );
  testWidgets('ordinary user has no staff entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StaffEntry(repo: ordinary)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
  });
  testWidgets('verified server role reveals staff entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StaffEntry(repo: staff)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Authorized moderation portal'), findsOneWidget);
  });
}
