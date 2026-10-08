import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../di/service_locator.dart';
import '../providers/settings_notifier.dart';
import '../services/cloud_sync_service.dart';
import '../utils/design_tokens.dart';
import '../widgets/app_logo.dart';
import '../widgets/folio_rule.dart';

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

class _PaywallScreenState extends State<PaywallScreen>
    with TickerProviderStateMixin {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  String? _price;
  ProductDetails? _product;
  bool _busy = true;
  bool _available = false;
  String? _error;

  // Animation controllers matching splash screen
  late final AnimationController _drawController;
  late final AnimationController _revealController;
  late final Animation<double> _drawProgress;
  late final Animation<double> _revealProgress;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdated);
    _loadStore();

    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _drawProgress = CurvedAnimation(
      parent: _drawController,
      curve: Curves.easeInOutCubic,
    );
    _revealProgress = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutBack,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reduceMotion = MediaQuery.disableAnimationsOf(context);
      if (_reduceMotion) {
        _drawController.value = 1.0;
        _revealController.value = 1.0;
        return;
      }
      _drawController.forward();
      _drawController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _revealController.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _drawController.dispose();
    _revealController.dispose();
    super.dispose();
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
        // No _error here: _ErrorState's title already shows
        // paywallStoreUnavailable; setting it would duplicate the line.
      });
      return;
    }
    final response = await _iap.queryProductDetails({_kProLifetime});
    if (!mounted) return;
    setState(() {
      _available = true;
      _busy = false;
      if (response.notFoundIDs.isNotEmpty) {
        _error = AppLocalizations.of(context).paywallProductMissing;
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
        // Mirror the verified purchase into the cloud account (no-op when
        // signed out) so Pro survives reinstalls and follows the user.
        if (getIt.isRegistered<CloudSyncService>()) {
          await getIt<CloudSyncService>().setPro(
            productId: purchase.productID,
            purchaseToken: purchase.verificationData.serverVerificationData,
          );
        }
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

  void _restore() {
    _iap.restorePurchases();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPro = context.watch<SettingsNotifier>().isPro;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColors.ground : AppColors.paper;
    final onSurface = isDark ? AppColors.paperOnGround : AppColors.ink;
    final onSurfaceVariant = isDark
        ? AppColors.paperOnGroundSoft
        : AppColors.inkSoft;
    final ruleColor = isDark ? AppColors.ruleOnGround : AppColors.rule;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s6,
            AppSpacing.s4,
            AppSpacing.s6,
            AppSpacing.s6,
          ),
          child: Column(
            children: [
              // Top bar with close button (or back)
              Row(
                children: [
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: l10n.closeSearchLabel,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        Icons.close,
                        color: onSurfaceVariant,
                        size: 24,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo arrival — matching splash (default 96, same as the
                        // native splash's launch_image size).
                        AppLogo(animation: _drawProgress),
                        const SizedBox(height: AppSpacing.s6),
                        // Wordmark — "Curated Feeds Pro"
                        FadeTransition(
                          opacity: _revealProgress,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(_revealProgress),
                            child: Text(
                              'Curated Feeds Pro',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        // Tagline — appears last
                        AnimatedBuilder(
                          animation: _revealProgress,
                          builder: (context, _) {
                            final subtitleProgress =
                                (_revealProgress.value - 0.4).clamp(0.0, 1.0) /
                                0.6;
                            return Opacity(
                              opacity: subtitleProgress,
                              child: Text(
                                l10n.paywallOneTime,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: onSurfaceVariant,
                                  letterSpacing: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        // Edition label (matching splash)
                        AnimatedBuilder(
                          animation: _revealProgress,
                          builder: (context, _) {
                            final subtitleProgress =
                                (_revealProgress.value - 0.4).clamp(0.0, 1.0) /
                                0.6;
                            return Opacity(
                              opacity: subtitleProgress,
                              child: Text(
                                l10n.splashEditionLabel(
                                  EditionState.current.toString().padLeft(
                                    4,
                                    '0',
                                  ),
                                ),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  color: onSurfaceVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                  letterSpacing: 1.4,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        // Divider rule
                        Container(width: 64, height: 1, color: ruleColor),
                        const SizedBox(height: AppSpacing.s8),
                        // Content
                        _busy
                            ? const Center(child: CircularProgressIndicator())
                            : !_available || _error != null
                            ? _ErrorState(
                                message: _error,
                                onRetry: _loadStore,
                                l10n: l10n,
                                onSurface: onSurface,
                                onSurfaceVariant: onSurfaceVariant,
                                ruleColor: ruleColor,
                              )
                            : isPro
                            ? _ProThanks(
                                onRestore: _restore,
                                l10n: l10n,
                                onSurface: onSurface,
                                onSurfaceVariant: onSurfaceVariant,
                              )
                            : _PurchaseContent(
                                l10n: l10n,
                                price: _price,
                                product: _product,
                                onBuy: _buy,
                                onRestore: _restore,
                                onSurface: onSurface,
                                onSurfaceVariant: onSurfaceVariant,
                                ruleColor: ruleColor,
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.l10n,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.ruleColor,
  });

  final String? message;
  final VoidCallback onRetry;
  final AppLocalizations l10n;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off_outlined, size: 48, color: onSurfaceVariant),
        const SizedBox(height: AppSpacing.s4),
        Text(
          l10n.paywallStoreUnavailable,
          style: AppType.headlineSmall(color: onSurface),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s2),
        if (message != null)
          Text(
            message!,
            style: AppType.bodyMedium(color: onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: AppSpacing.s6),
        FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8,
              vertical: AppSpacing.s4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          child: Text(
            l10n.retryCta,
            style: AppType.labelLarge(
              color: Colors.white,
            ).copyWith(letterSpacing: 1.2),
          ),
        ),
      ],
    );
  }
}

class _PurchaseContent extends StatelessWidget {
  const _PurchaseContent({
    required this.l10n,
    required this.price,
    required this.product,
    required this.onBuy,
    required this.onRestore,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.ruleColor,
  });

  final AppLocalizations l10n;
  final String? price;
  final ProductDetails? product;
  final VoidCallback onBuy;
  final VoidCallback onRestore;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.paywallHeading,
          style: AppType.displayMedium(color: onSurface),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s6),
        if (price != null)
          Text(price!, style: AppType.titleLarge(color: AppColors.primary)),
        const SizedBox(height: AppSpacing.s8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: product != null ? onBuy : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: AppSpacing.s4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              l10n.buyOnce(price ?? ''),
              style: AppType.labelLarge(
                color: Colors.white,
              ).copyWith(letterSpacing: 1.2),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        TextButton(
          onPressed: onRestore,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s6,
              vertical: AppSpacing.s3,
            ),
          ),
          child: Text(
            l10n.restorePurchase,
            style: AppType.monoEyebrow(
              color: onSurfaceVariant,
            ).copyWith(letterSpacing: 1.0),
          ),
        ),
      ],
    );
  }
}

class _ProThanks extends StatelessWidget {
  const _ProThanks({
    required this.onRestore,
    required this.l10n,
    required this.onSurface,
    required this.onSurfaceVariant,
  });

  final VoidCallback onRestore;
  final AppLocalizations l10n;
  final Color onSurface;
  final Color onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 64,
          color: Color(0xFF057A55), // Deep emerald from constants
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(l10n.proThanks, style: AppType.displayMedium(color: onSurface)),
        const SizedBox(height: AppSpacing.s2),
        Text(
          l10n.proThanksBody,
          style: AppType.bodyMedium(color: onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.s6),
        TextButton(
          onPressed: onRestore,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s6,
              vertical: AppSpacing.s3,
            ),
          ),
          child: Text(
            l10n.restorePurchase,
            style: AppType.monoEyebrow(
              color: onSurfaceVariant,
            ).copyWith(letterSpacing: 1.0),
          ),
        ),
      ],
    );
  }
}
