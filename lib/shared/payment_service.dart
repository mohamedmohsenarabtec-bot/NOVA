/// A provider adapter must return server-verified state, never grant locally.
abstract interface class PaymentService {
  Future<Uri> hostedCheckout(String productId);
  Future<void> purchaseStoreProduct(String productId);
  Future<void> restorePurchases();
}

class PaymentsNotConfigured implements PaymentService {
  Never _unavailable() => throw StateError(
    'Configure a store provider and server receipt verification first.',
  );
  @override
  Future<Uri> hostedCheckout(String productId) async => _unavailable();
  @override
  Future<void> purchaseStoreProduct(String productId) async => _unavailable();
  @override
  Future<void> restorePurchases() async => _unavailable();
}
