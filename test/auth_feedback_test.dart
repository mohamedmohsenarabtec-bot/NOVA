import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/core/config.dart';
import 'package:nova/core/strings.dart';
import 'package:nova/features/auth/auth_feedback.dart';

void main() {
  test('immediate signup session does not ask for email confirmation', () {
    final message = signupFeedback(const Strings(false), SignupResult.signedIn);
    expect(message, contains('signed in'));
    expect(message, isNot(contains('confirm')));
  });
  test('email confirmation required explains actual server state', () {
    expect(
      signupFeedback(const Strings(false), SignupResult.confirmationRequired),
      contains('Confirm email'),
    );
  });
  test(
    'auth errors distinguish credentials, duplicate, rate limit and network',
    () {
      const s = Strings(false);
      expect(
        authFeedback(
          s,
          const AuthException('not shown', code: 'invalid_credentials'),
        ),
        contains('incorrect'),
      );
      expect(
        authFeedback(
          s,
          const AuthException('not shown', code: 'user_already_exists'),
        ),
        contains('already exists'),
      );
      expect(
        authFeedback(
          s,
          const AuthException('not shown', code: 'over_request_rate_limit'),
        ),
        contains('Too many'),
      );
      expect(
        authFeedback(s, TimeoutException('not shown')),
        contains('network'),
      );
      expect(
        authFeedback(
          const Strings(true),
          const AuthException('not shown', code: 'invalid_credentials'),
        ),
        contains('غير صحيحة'),
      );
    },
  );
  test('server diagnostics and tokens are never displayed', () {
    expect(
      authFeedback(
        const Strings(false),
        const AuthException('sensitive diagnostic'),
      ),
      isNot(contains('sensitive')),
    );
  });
  test('client configuration accepts public keys and rejects privileged keys and API subpaths', () {
    const url = 'https://example.supabase.co';
    expect(ClientConfig.valid(url, 'sb_publishable_public-test-value'), isTrue);
    expect(
      ClientConfig.valid('$url/rest/v1/', 'sb_publishable_public-test-value'),
      isFalse,
    );
    expect(ClientConfig.valid(url, 'sb_secret_not-a-real-key'), isFalse);
    String token(String role) =>
        'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.signature';
    expect(ClientConfig.valid(url, token('anon')), isTrue);
    expect(ClientConfig.valid(url, token('service_role')), isFalse);
    expect(
      ClientConfig.valid('http://untrusted.example', token('anon')),
      isFalse,
    );
  });
}
