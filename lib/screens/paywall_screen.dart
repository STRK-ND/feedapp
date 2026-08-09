import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../providers/settings_notifier.dart';
import '../utils/constants.dart';

/// Play Console product ID for the lifetime Pro upgrade.
const _kProLifetime = 'cf_pro_lifetime';

/// Lifetime-purchase paywall. One product, Buy + Restore, that's it.
// ponytail: no server-side receipt validation — local isPro flip + Play's
// verified purchase stream is acceptable at this price point. Add server
// validation (e.g. Firebase Functions) when revenue justifies the infra.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  String? _price;
  ProductDetails? _product;
  bool _busy = true;
  bool _available = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdated);
    _loadStore();
  }

  Future<void> _loadStore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final available = await _iap.isAvailable();
    if (!available) {
      setState(() {
        _available = false;
        _busy = false;
        _error = 'Store unavailable. Check your connection and Play Store.';
      });
      return;
    }
    final response = await _iap.queryProductDetails({_kProLifetime});
    if (!mounted) return;
    setState(() {
      _available = true;
      _busy = false;
      if (response.notFoundIDs.isNotEmpty) {
        _error = 'Product not found in the store yet.';
      } else if (response.productDetails.isNotEmpty) {
        _product = response.productDetails.first;
        _price = _product!.price;
      }
    });
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != _kProLifetime) continue;
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (!mounted) continue;
        final notifier = context.read<SettingsNotifier>();
        await notifier.setIsPro(true);
      } else if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(purchase.error?.message ?? 'Purchase failed'),
            ),
          );
        }
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  void _buy() {
    final product = _product;
    if (product == null) return;
    _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<SettingsNotifier>().isPro;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Curated Feeds Pro')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: isPro
              ? _ProThanks(onRestore: _restore)
              : _busy
              ? const CircularProgressIndicator()
              : !_available || _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? 'Store unavailable',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadStore,
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.workspace_premium_outlined,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Support Curated Feeds',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'One-time purchase, yours forever.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    if (_price != null)
                      Text(
                        _price!,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _product != null ? _buy : null,
                        child: Text('Buy once — ${_price ?? ''}'),
                      ),
                    ),
                    TextButton(
                      onPressed: _restore,
                      child: const Text('Restore purchase'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _restore() {
    _iap.restorePurchases();
  }
}

class _ProThanks extends StatelessWidget {
  const _ProThanks({required this.onRestore});

  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 64,
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        Text('You\'re Pro!', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Thanks for supporting Curated Feeds.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        TextButton(onPressed: onRestore, child: const Text('Restore purchase')),
      ],
    );
  }
}
