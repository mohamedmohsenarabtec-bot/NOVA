// Test fixtures only; never included in the app or database seed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/features/auth/auth_screen.dart';
import 'package:nova/features/onboarding/onboarding_screen.dart';
import 'package:nova/features/discover/discover_screen.dart';
import 'package:nova/features/chat/chat_screen.dart';
import 'package:nova/features/subscriptions/plans_screen.dart';
import 'package:nova/features/admin/admin_screen.dart';
import 'package:nova/shared/repository.dart';

class TestRepository extends NovaRepository {
  TestRepository()
    : super(SupabaseClient('https://test.invalid', 'test-public-key'));
  final saved = <DbRow>[];
  final sent = <String>[];
  bool showProfile = false;
  @override
  String get uid => 'test-user';
  @override
  Future<void> saveProfile(DbRow values) async {
    saved.add(values);
  }

  @override
  Future<List<DbRow>> discover({int page = 0}) async => showProfile
      ? [
          {
            'id': 'test-other',
            'display_name': 'Test Person',
            'age': 25,
            'shared_interests': 2,
          },
        ]
      : [];
  @override
  Future<bool> act(String target, String kind) async => kind == 'like';
  @override
  Future<List<DbRow>> conversations() async => [];
  @override
  Future<List<DbRow>> messages(String id, {DateTime? before}) async => [];
  @override
  Future<void> send(String id, String body) async {
    sent.add(body);
  }

  @override
  Future<RealtimeChannel?> watchMessages(
    String id,
    void Function() changed,
  ) async => null;
  @override
  Future<List<DbRow>> plans() async => [];
  @override
  Future<List<DbRow>> roles() async => [];
  @override
  Future<List<DbRow>> queue() async => [];
}

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));
void main() {
  late TestRepository repo;
  setUp(() => repo = TestRepository());
  tearDown(() => repo.client.dispose());
  testWidgets('auth rejects malformed email without calling backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AuthScreen(
          repo: repo,
          languageButton: const SizedBox(),
          recovery: false,
          onRecovered: () {},
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'bad-email');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
  });
  testWidgets('onboarding saves progress before advancing', (tester) async {
    await tester.pumpWidget(
      host(OnboardingScreen(repo: repo, onComplete: () {})),
    );
    await tester.enterText(find.byType(TextField), 'Test Adult');
    await tester.pump();
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();
    expect(repo.saved.single['onboarding_step'], 1);
    expect(find.text('Who would you like to meet?'), findsOneWidget);
  });
  testWidgets(
    'preview recovery explains missing delivery without an email request',
    (tester) async {
      await tester.pumpWidget(
        host(
          AuthScreen(
            repo: repo,
            languageButton: const SizedBox(),
            recovery: false,
            onRecovered: () {},
          ),
        ),
      );
      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No email was sent'), findsOneWidget);
    },
  );
  testWidgets('discovery honest empty state', (tester) async {
    await tester.pumpWidget(host(DiscoverScreen(repo: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Good connections take time'), findsOneWidget);
  });
  testWidgets(
    'profile card likes create match feedback only on server result',
    (tester) async {
      repo.showProfile = true;
      await tester.pumpWidget(host(DiscoverScreen(repo: repo)));
      await tester.pumpAndSettle();
      expect(find.text('Test Person، 25'), findsOneWidget);
      await tester.tap(find.text('Like'));
      await tester.pumpAndSettle();
      expect(find.text('A mutual spark!'), findsOneWidget);
    },
  );
  testWidgets('conversation list explains mutual matching', (tester) async {
    await tester.pumpWidget(host(ConversationList(repo: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Room for a first hello'), findsOneWidget);
  });
  testWidgets('First Spark fills composer and sends text through repository', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(ChatScreen(repo: repo, conversationId: 'test-conversation')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use First Spark'));
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(repo.sent, ['What small thing instantly improves your day?']);
  });
  testWidgets('subscription screen does not invent paid products', (
    tester,
  ) async {
    await tester.pumpWidget(host(PlansScreen(repo: repo)));
    await tester.pumpAndSettle();
    expect(find.text('No paid plans are enabled yet.'), findsOneWidget);
  });
  testWidgets('admin screen denies ordinary users', (tester) async {
    await tester.pumpWidget(host(AdminScreen(repo: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Restricted access'), findsOneWidget);
  });
}
