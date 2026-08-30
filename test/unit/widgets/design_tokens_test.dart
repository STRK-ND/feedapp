import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:curatedfeeds/utils/design_tokens.dart';
import 'package:curatedfeeds/utils/constants.dart' as constants;

/// Drift guard for the curated-feeds design spec (§3.1 palette table).
///
/// If someone edits a hex in `design_tokens.dart` (or the category
/// accents in `constants.dart`), the spec in
/// `docs/superpowers/specs/2026-07-11-curated-feeds-redesign-design.md`
/// and the code will disagree. These assertions pin the code to the
/// spec so the mismatch surfaces as a test failure, not a silent
/// visual regression.
void main() {
  group('Design tokens match the curated-feeds spec', () {
    test('palette §3.1 — primary + light-mode surfaces and ink', () {
      // Values follow the dark-first reskin (see design_tokens.dart header
      // comment): paper is a matched-but-secondary light path and the ink
      // ramp was re-tuned. The old spec §3.1 hexes (#F7F5F8 / #1A1B2E /
      // #6B7280 / #9CA3AF) are superseded.
      expect(AppColors.primary, const Color(0xFFC4944E));
      expect(AppColors.paper, const Color(0xFFF4F1F8));
      expect(AppColors.paperRaised, const Color(0xFFFFFFFF));
      expect(AppColors.ink, const Color(0xFF15131C));
      expect(AppColors.inkSoft, const Color(0xFF6B6877));
      expect(AppColors.inkFaint, const Color(0xFF9A97A6));
      expect(AppColors.rule, const Color(0xFFE5E7EB));
    });

    test('palette §3.1 — dark-mode ground + paper-on-ground', () {
      expect(AppColors.ground, const Color(0xFF0E0814));
      expect(AppColors.groundElev, const Color(0xFF1A1423));
      expect(AppColors.paperOnGround, const Color(0xFFF8F7F4));
      expect(AppColors.ruleOnGround, const Color(0xFF27212E));
    });

    test('palette §3.1 — sepia and e-ink reader themes', () {
      expect(AppColors.sepiaGround, const Color(0xFFF4ECD8));
      expect(AppColors.sepiaText, const Color(0xFF3E2C1C));
      expect(AppColors.sepiaAccent, const Color(0xFF8C6E45));
      expect(AppColors.einkGround, const Color(0xFF000000));
      expect(AppColors.einkText, const Color(0xFFE8E2D9));
    });

    test('palette §3.1 — category accents kept in constants AppColors', () {
      expect(constants.AppColors.techPrimary, const Color(0xFF3B82F6));
      expect(constants.AppColors.newsPrimary, const Color(0xFFDC2626));
      expect(constants.AppColors.sciencePrimary, const Color(0xFF0891B2));
      expect(constants.AppColors.sportsPrimary, const Color(0xFF059669));
      expect(constants.AppColors.entertainmentPrimary, const Color(0xFF7C3AED));
      expect(constants.AppColors.gamingPrimary, const Color(0xFF8B5CF6));
    });
  });
}
