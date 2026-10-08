import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:curatedfeeds/utils/design_tokens.dart';
import 'package:curatedfeeds/widgets/app_logo.dart';

/// Guards for the shared brand mark that replaced the byte-duplicated
/// `_FolioGlyphPainter`.
///
/// The asset itself is verified by `tool/generate_brand_assets.py`, which
/// asserts its own extraction invariants. What matters here is the widget
/// contract the four call sites depend on.
void main() {
  /// Pumps [AppLogo] on its own so `find.byType(AppLogo)` resolves without
  /// the surrounding screen scaffolding.
  Future<void> pumpLogo(WidgetTester tester, AppLogo logo) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: logo)),
      ),
    );
  }

  group('AppLogo', () {
    testWidgets('renders the brand asset at the requested size', (
      tester,
    ) async {
      await pumpLogo(tester, const AppLogo(size: 64));

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect(
        (image.image as AssetImage).assetName,
        'assets/brand/logo.png',
        reason: 'the logo is shipped as a committed asset from pubspec.yaml',
      );

      final logo = tester.getSize(find.byType(AppLogo));
      expect(logo.width, 64);
      expect(logo.height, 64);
    });

    testWidgets('defaults to the size the native splash hands over at', (
      tester,
    ) async {
      await pumpLogo(tester, const AppLogo());

      // launch_image.png is generated at 96dp in every density bucket, so a
      // mismatch here would make the logo jump between the native splash and
      // the Flutter splash.
      expect(tester.getSize(find.byType(AppLogo)).width, 96);
    });

    testWidgets('stays square for any size', (tester) async {
      for (final size in [32.0, 40.0, 48.0, 96.0]) {
        await pumpLogo(tester, AppLogo(size: size));
        final box = tester.getSize(find.byType(AppLogo));
        expect(box.width, size);
        expect(box.height, size, reason: 'the brand tile is square');
      }
    });

    /// Reads the x-scale of the `Transform.scale` the widget applies.
    ///
    /// `Transform.scale` builds `diag(s, s, 1)`, so `getMaxScaleOnAxis()`
    /// returns 1 regardless of `s` — the third singular value is the
    /// untouched z component. Read m11 directly instead.
    double logoScale(WidgetTester tester) => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(AppLogo),
            matching: find.byType(Transform),
          ),
        )
        .transform
        .storage[0];

    double logoOpacity(WidgetTester tester) => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(AppLogo),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;

    testWidgets('with no animation it renders fully opaque and unscaled', (
      tester,
    ) async {
      await pumpLogo(tester, const AppLogo(size: 48));

      // Scoped to AppLogo: the MaterialApp/Scaffold scaffold brings its own
      // Transform widgets.
      expect(
        find.descendant(
          of: find.byType(AppLogo),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppLogo),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });

    testWidgets('animation tracks the caller across its full timeline', (
      tester,
    ) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 1000),
      );
      addTearDown(controller.dispose);

      await pumpLogo(tester, AppLogo(size: 48, animation: controller));

      // Start: fully transparent, and deliberately not yet painted at all so
      // the splash never rasterises an invisible image.
      expect(logoOpacity(tester), 0.0);

      // Mid-timeline: the widget applies no easing of its own — both callers
      // already drive this with an eased controller — so the fade tracks the
      // raw value and the scale sits halfway through its 0.94..1.00 range.
      controller.value = 0.5;
      await tester.pump();
      expect(logoOpacity(tester), 0.5);
      expect(logoScale(tester), closeTo(0.97, 0.001));

      // End: fully arrived, at rest.
      controller.value = 1.0;
      await tester.pump();
      expect(logoOpacity(tester), 1.0);
      expect(logoScale(tester), 1.0);
    });

    testWidgets('clamps overshooting curves instead of inheriting them', (
      tester,
    ) async {
      // The wordmark's sibling curve is `easeOutBack`, which exceeds 1.0
      // mid-flight. The logo must never overshoot past rest no matter what
      // the caller drives it with — driving these values through a real
      // controller is impossible (out-of-bounds throws), so pin the value.
      await pumpLogo(
        tester,
        const AppLogo(size: 48, animation: AlwaysStoppedAnimation(1.15)),
      );
      expect(logoOpacity(tester), 1.0);
      expect(logoScale(tester), 1.0);

      await pumpLogo(
        tester,
        const AppLogo(size: 48, animation: AlwaysStoppedAnimation(-0.2)),
      );
      expect(logoOpacity(tester), 0.0);
      expect(logoScale(tester), closeTo(0.94, 0.001));
    });
  });

  group('AppLogo and the design tokens', () {
    test('the ground the asset pipeline targets still matches the app', () {
      // tool/generate_brand_assets.py hardcodes GROUND (the adaptive-icon
      // background, the Play de-corner fill) and AMBER (the feature-graphic
      // rule) because Flutter has no build-time access to these, and
      // values/colors.xml duplicates ground/paper for the native splash. If
      // the palette is retuned, the script must be re-run and the XML
      // updated — this pins the values they depend on so the drift surfaces
      // here, not in the store listing or the launch window.
      expect(AppColors.ground, const Color(0xFF0E0814));
      expect(AppColors.curation, const Color(0xFFC4944E));
      expect(AppColors.paper, const Color(0xFFF4F1F8));
    });
  });
}
