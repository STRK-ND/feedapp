/// Reader themes — four distinct visual treatments for the article
/// reader view. Each one specifies ground, ink, soft, accent, and rule.
///
/// `default` follows the app theme (light or dark).
/// `sepia` is the warm paperback.
/// `eInk` is OLED true-black with warm white.
/// `paper` is the cream-paper light.
import 'package:flutter/material.dart';
import 'design_tokens.dart';

enum ReaderTheme {
  defaultTheme,
  sepia,
  eInk,
  paper;

  String get label {
    switch (this) {
      case ReaderTheme.defaultTheme:
        return 'Default';
      case ReaderTheme.sepia:
        return 'Sepia';
      case ReaderTheme.eInk:
        return 'E-Ink';
      case ReaderTheme.paper:
        return 'Paper';
    }
  }
}

class ReaderPalette {
  final Color ground;
  final Color text;
  final Color soft;
  final Color accent;
  final Color rule;

  const ReaderPalette({
    required this.ground,
    required this.text,
    required this.soft,
    required this.accent,
    required this.rule,
  });

  static ReaderPalette forTheme({
    required ReaderTheme theme,
    required Brightness appBrightness,
    double fontSize = 16,
    double lineHeight = 1.6,
  }) {
    switch (theme) {
      case ReaderTheme.sepia:
        return const ReaderPalette(
          ground: AppColors.sepiaGround,
          text: AppColors.sepiaText,
          soft: AppColors.sepiaSoft,
          accent: AppColors.sepiaAccent,
          rule: AppColors.sepiaRule,
        );
      case ReaderTheme.eInk:
        return const ReaderPalette(
          ground: AppColors.einkGround,
          text: AppColors.einkText,
          soft: Color(0xFF8A8479),
          accent: AppColors.primary,
          rule: AppColors.einkRule,
        );
      case ReaderTheme.paper:
        return const ReaderPalette(
          ground: AppColors.paper,
          text: AppColors.ink,
          soft: AppColors.inkSoft,
          accent: AppColors.primary,
          rule: AppColors.rule,
        );
      case ReaderTheme.defaultTheme:
        if (appBrightness == Brightness.dark) {
          return const ReaderPalette(
            ground: AppColors.ground,
            text: AppColors.paperOnGround,
            soft: AppColors.paperOnGroundSoft,
            accent: AppColors.primary,
            rule: AppColors.ruleOnGround,
          );
        }
        return const ReaderPalette(
          ground: AppColors.paperRaised,
          text: AppColors.ink,
          soft: AppColors.inkSoft,
          accent: AppColors.primary,
          rule: AppColors.rule,
        );
    }
  }
}

/// Reading preferences persisted via SettingsService (settings_notifier).
class ReadingPreferences {
  final ReaderTheme theme;
  final double fontSize; // 14..22
  final double lineHeight; // 1.4..1.8
  final bool monoDatelines;
  final bool widenMeasure; // 64ch vs 70ch
  final String bodyFont; // 'dm' | 'lora'

  const ReadingPreferences({
    this.theme = ReaderTheme.defaultTheme,
    this.fontSize = 16,
    this.lineHeight = 1.6,
    this.monoDatelines = true,
    this.widenMeasure = false,
    this.bodyFont = 'dm',
  });

  ReadingPreferences copyWith({
    ReaderTheme? theme,
    double? fontSize,
    double? lineHeight,
    bool? monoDatelines,
    bool? widenMeasure,
    String? bodyFont,
  }) =>
      ReadingPreferences(
        theme: theme ?? this.theme,
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        monoDatelines: monoDatelines ?? this.monoDatelines,
        widenMeasure: widenMeasure ?? this.widenMeasure,
        bodyFont: bodyFont ?? this.bodyFont,
      );
}
