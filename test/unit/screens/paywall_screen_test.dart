import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// InAppPurchasePlatform lives in the platform-interface package (the main
// in_app_purchase export hides it); it is a transitive dependency, so the
// depend_on_referenced_packages lint fires — accepted for this fake.
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:curatedfeeds/providers/settings_notifier.dart';
import 'package:curatedfeeds/screens/paywall_screen.dart';
import 'package:curatedfeeds/services/settings_service.dart';

/// Minimal InAppPurchasePlatform fake. The screen only ever reaches
/// `isAvailable()` when the store is unavailable, so a `false` answer is
/// all the real flow needs; the remaining members exist so nothing falls
/// through to the base class's `UnimplementedError`.
class _FakeIAP extends InAppPurchasePlatform {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      const Stream<List<PurchaseDetails>>.empty();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: [],
      notFoundIDs: identifiers.toList(),
    );
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}
}

InAppPurchasePlatform _currentPlatform() {
  // The platform instance is `late` and unset until first assigned;
  // treat an unset instance as a safe no-op so tearDown always restores.
  try {
    return InAppPurchasePlatform.instance;
  } catch (_) {
    return _FakeIAP();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InAppPurchasePlatform previousPlatform;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // InAppPurchase._getOrCreateInstance() calls registerPlatform() on first
    // access, which OVERWRITES InAppPurchasePlatform.instance with the real
    // Android platform (whose MethodChannel never resolves in a widget test).
    // Create the facade first, then install the fake underneath it.
    InAppPurchase.instance;
    previousPlatform = _currentPlatform();
    InAppPurchasePlatform.instance = _FakeIAP();
  });

  tearDown(() {
    InAppPurchasePlatform.instance = previousPlatform;
  });

  testWidgets('renders store-unavailable state when the store is not '
      'available', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsNotifier>(
        create: (_) => SettingsNotifier(SettingsService()),
        child: const MaterialApp(home: PaywallScreen()),
      ),
    );

    // Let _loadStore() complete (fake isAvailable() returns false
    // immediately) and the unavailable state render.
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Store unavailable. Check your connection and Play Store.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    // No purchase CTA (Buy once / Restore) is shown while unavailable.
    expect(find.textContaining('Buy'), findsNothing);
    expect(find.text('Restore purchase'), findsNothing);
  });

  // ponytail: full purchase flow test deferred until revenue logic
  // depends on it — exercising queryProductDetails -> purchase ->
  // setIsPro needs a purchase-stream completer + SettingsNotifier wiring,
  // disproportionately expensive for a render-level assertion.
}
