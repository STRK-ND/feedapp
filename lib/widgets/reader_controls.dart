/// Reader controls — theme swatches + Aa panel for the
/// ExpandedArticleCard (reader view).
///
/// Theme switcher is always visible at the top of the article.
/// Aa panel opens as a bottom sheet on tap of the Aa tile.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/design_tokens.dart';
import '../utils/reader_theme.dart';

class ReaderControls extends StatelessWidget {
  final ReaderTheme currentTheme;
  final double fontSize;
  final double lineHeight;
  final bool widenMeasure;
  final String bodyFont;
  final ValueChanged<ReaderTheme> onTheme;
  final ValueChanged<double> onFontSize;
  final ValueChanged<double> onLineHeight;
  final ValueChanged<bool> onWidenMeasure;
  final ValueChanged<String> onBodyFont;

  const ReaderControls({
    super.key,
    required this.currentTheme,
    required this.fontSize,
    required this.lineHeight,
    required this.widenMeasure,
    required this.bodyFont,
    required this.onTheme,
    required this.onFontSize,
    required this.onLineHeight,
    required this.onWidenMeasure,
    required this.onBodyFont,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ThemeSwatches(
          current: currentTheme,
          onChange: onTheme,
        ),
        _AaButton(
          fontSize: fontSize,
          lineHeight: lineHeight,
          widenMeasure: widenMeasure,
          bodyFont: bodyFont,
          onFontSize: onFontSize,
          onLineHeight: onLineHeight,
          onWidenMeasure: onWidenMeasure,
          onBodyFont: onBodyFont,
          theme: currentTheme,
        ),
      ],
    );
  }
}

class _ThemeSwatches extends StatelessWidget {
  final ReaderTheme current;
  final ValueChanged<ReaderTheme> onChange;

  const _ThemeSwatches({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    Widget swatch(ReaderTheme t, Color c) {
      final selected = current == t;
      return Semantics(
        button: true,
        label: '${t.label} reader theme',
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChange(t),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : AppColors.rule.withValues(alpha: 0.6),
                width: selected ? 2.5 : 1,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch(ReaderTheme.defaultTheme, AppColors.paperRaised),
        const SizedBox(width: AppSpacing.s2),
        swatch(ReaderTheme.sepia, AppColors.sepiaGround),
        const SizedBox(width: AppSpacing.s2),
        swatch(ReaderTheme.paper, AppColors.paper),
        const SizedBox(width: AppSpacing.s2),
        swatch(ReaderTheme.eInk, AppColors.einkGround),
      ],
    );
  }
}

class _AaButton extends StatelessWidget {
  final ReaderTheme theme;
  final double fontSize;
  final double lineHeight;
  final bool widenMeasure;
  final String bodyFont;
  final ValueChanged<double> onFontSize;
  final ValueChanged<double> onLineHeight;
  final ValueChanged<bool> onWidenMeasure;
  final ValueChanged<String> onBodyFont;

  const _AaButton({
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
    required this.widenMeasure,
    required this.bodyFont,
    required this.onFontSize,
    required this.onLineHeight,
    required this.onWidenMeasure,
    required this.onBodyFont,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSheet(context),
        borderRadius: BorderRadius.circular(AppRadius.button),
        // 48x48 hit area — Android tap-target floor.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Tooltip(
            message: 'Type & spacing',
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
              child: Text(
                'Aa',
                style: AppType.titleLarge(
                  color: AppColors.primary,
                ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _AaPanel(
          fontSize: fontSize,
          lineHeight: lineHeight,
          widenMeasure: widenMeasure,
          bodyFont: bodyFont,
          onFontSize: onFontSize,
          onLineHeight: onLineHeight,
          onWidenMeasure: onWidenMeasure,
          onBodyFont: onBodyFont,
        );
      },
    );
  }
}

class _AaPanel extends StatefulWidget {
  final double fontSize;
  final double lineHeight;
  final bool widenMeasure;
  final String bodyFont;
  final ValueChanged<double> onFontSize;
  final ValueChanged<double> onLineHeight;
  final ValueChanged<bool> onWidenMeasure;
  final ValueChanged<String> onBodyFont;

  const _AaPanel({
    required this.fontSize,
    required this.lineHeight,
    required this.widenMeasure,
    required this.bodyFont,
    required this.onFontSize,
    required this.onLineHeight,
    required this.onWidenMeasure,
    required this.onBodyFont,
  });

  @override
  State<_AaPanel> createState() => _AaPanelState();
}

class _AaPanelState extends State<_AaPanel> {
  late double _fontSize = widget.fontSize;
  late double _lineHeight = widget.lineHeight;
  late bool _widenMeasure = widget.widenMeasure;
  late String _bodyFont = widget.bodyFont;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final groundColor = brightness == Brightness.dark
        ? AppColors.groundElev
        : AppColors.paperRaised;
    final ink = brightness == Brightness.dark
        ? AppColors.paperOnGround
        : AppColors.ink;
    return Container(
      decoration: BoxDecoration(
        color: groundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, -16),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s3,
        AppSpacing.s6,
        AppSpacing.s8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.rule,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text('Type & spacing', style: AppType.titleLarge(color: ink)),
          const SizedBox(height: AppSpacing.s5),
          // Live preview
          Container(
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: AppColors.paperRaised,
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(color: AppColors.rule),
            ),
            child: Text(
              'A river of words at the\nsize you prefer.',
              style: AppType.displayMedium(color: AppColors.ink).copyWith(
                fontSize: _fontSize,
                height: _lineHeight,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          Row(
            children: [
              Text(
                'FONT SIZE',
                style: AppType.monoEyebrow(color: AppColors.inkSoft),
              ),
              const Spacer(),
              Text(
                '${_fontSize.round()} PT',
                style: AppType.monoDateline(color: AppColors.primary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Slider(
            value: _fontSize.clamp(14, 22).toDouble(),
            min: 14,
            max: 22,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.primary.withValues(alpha: 0.2),
            onChanged: (v) {
              setState(() => _fontSize = v);
              widget.onFontSize(v);
            },
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Text(
                'LINE HEIGHT',
                style: AppType.monoEyebrow(color: AppColors.inkSoft),
              ),
              const Spacer(),
              Text(
                _lineHeight.toStringAsFixed(2),
                style: AppType.monoDateline(color: AppColors.primary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Slider(
            value: _lineHeight.clamp(1.4, 1.8),
            min: 1.4,
            max: 1.8,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.primary.withValues(alpha: 0.2),
            onChanged: (v) {
              setState(() => _lineHeight = v);
              widget.onLineHeight(v);
            },
          ),
          const SizedBox(height: AppSpacing.s3),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'WIDEN MEASURE',
              style: AppType.monoEyebrow(color: AppColors.inkSoft),
            ),
            subtitle: Text(
              'Cap line length at 64 characters. Reads as a column.',
              style: AppType.bodyMedium(color: AppColors.ink),
            ),
            value: _widenMeasure,
            activeThumbColor: AppColors.primary,
            onChanged: (v) {
              setState(() => _widenMeasure = v);
              widget.onWidenMeasure(v);
            },
          ),
          const SizedBox(height: AppSpacing.s3),
          // Body font — DM Sans (default) vs Lora (editorial contrast).
          Row(
            children: [
              Text(
                'BODY FONT',
                style: AppType.monoEyebrow(color: AppColors.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          _BodyFontSegment(
            value: _bodyFont,
            onChange: (v) {
              setState(() => _bodyFont = v);
              widget.onBodyFont(v);
            },
          ),
        ],
      ),
    );
  }
}

/// Two-up segmented control for body font. Live preview, mono labels,
/// amber accent.
class _BodyFontSegment extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;
  const _BodyFontSegment({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.rule),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _Segment(
            label: 'DM SANS',
            sample: 'Aa',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
            selected: value == 'dm',
            onTap: () => onChange('dm'),
          ),
          _Segment(
            label: 'LORA',
            sample: 'Aa',
            style: GoogleFonts.lora(
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
            selected: value == 'lora',
            onTap: () => onChange('lora'),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final String sample;
  final TextStyle style;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.sample,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s3,
            horizontal: AppSpacing.s2,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: selected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sample,
                style: style.copyWith(fontSize: 22, height: 1.0),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                label,
                style: AppType.monoEyebrow(
                  color: selected ? AppColors.primary : AppColors.inkSoft,
                ).copyWith(letterSpacing: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
