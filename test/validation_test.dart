import 'package:flutter_test/flutter_test.dart';
import 'package:nova/core/validation.dart';
import 'package:nova/shared/payment_service.dart';

void main() {
  test('email rejects malformed addresses', () {
    expect(Validation.email('owner@example.com'), isTrue);
    for (final input in ['', 'a', '@example.com', 'a@b', 'a b@example.com']) {
      expect(Validation.email(input), isFalse);
    }
  });
  test('password has minimum twelve characters', () {
    expect(Validation.password('12345678901'), isFalse);
    expect(Validation.password('a strong phrase'), isTrue);
  });
  test('age restriction handles birthday boundaries and future dates', () {
    final now = DateTime(2026, 10, 21);
    expect(Validation.adult(DateTime(2008, 10, 21), now), isTrue);
    expect(Validation.adult(DateTime(2008, 10, 22), now), isFalse);
    expect(Validation.adult(DateTime(2030), now), isFalse);
    expect(Validation.adult(DateTime(2000, 2, 29), now), isTrue);
  });
  test('unconfigured payments fail closed', () async {
    final payments = PaymentsNotConfigured();
    await expectLater(payments.hostedCheckout('plus'), throwsStateError);
    await expectLater(payments.purchaseStoreProduct('plus'), throwsStateError);
    await expectLater(payments.restorePurchases(), throwsStateError);
  });
}
