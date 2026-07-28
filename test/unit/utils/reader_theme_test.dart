import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/utils/design_tokens.dart';
import 'package:curatedfeeds/utils/reader_theme.dart';

void main() {
  group('ReaderPalette.forTheme', () {
    test('sepia uses sepia tokens regardless of brightness', () {
      final dark = ReaderPalette.forTheme(
        theme: ReaderTheme.sepia,
        appBrightness: Brightness.dark,
      );
      final light = ReaderPalette.forTheme(
        theme: ReaderTheme.sepia,
        appBrightness: Brightness.light,
      );
      expect(dark.ground, AppColors.sepiaGround);
      expect(light.ground, AppColors.sepiaGround);
      expect(dark.text, AppColors.sepiaText);
    });

    test('eInk uses eink tokens regardless of brightness', () {
      final dark = ReaderPalette.forTheme(
        theme: ReaderTheme.eInk,
        appBrightness: Brightness.dark,
      );
      final light = ReaderPalette.forTheme(
        theme: ReaderTheme.eInk,
        appBrightness: Brightness.light,
      );
      expect(dark.ground, AppColors.einkGround);
      expect(light.ground, AppColors.einkGround);
      expect(dark.text, AppColors.einkText);
    });

    test('paper uses paper tokens regardless of brightness', () {
      final dark = ReaderPalette.forTheme(
        theme: ReaderTheme.paper,
        appBrightness: Brightness.dark,
      );
      final light = ReaderPalette.forTheme(
        theme: ReaderTheme.paper,
        appBrightness: Brightness.light,
      );
      expect(dark.ground, AppColors.paper);
      expect(light.ground, AppColors.paper);
    });

    test('default swaps between dark and light palette', () {
      final dark = ReaderPalette.forTheme(
        theme: ReaderTheme.defaultTheme,
        appBrightness: Brightness.dark,
      );
      final light = ReaderPalette.forTheme(
        theme: ReaderTheme.defaultTheme,
        appBrightness: Brightness.light,
      );
      expect(dark.ground, isNot(light.ground));
      expect(dark.text, isNot(light.text));
      expect(dark.ground, AppColors.ground);
      expect(light.ground, AppColors.paperRaised);
    });
  });
}
