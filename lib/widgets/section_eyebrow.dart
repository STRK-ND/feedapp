/// Section eyebrow — uppercase monospace label + hairline rule that
/// reveals from left to right. Used in time-grouped feed list:
///
///   TODAY · 14 ARTICLES
///   ──────────────────────────────────────────
///
/// Variants by recency: the widget renders different vertical padding
/// (denser for older sections) to encode recency through typography/layout.
library;

import 'package:flutter/material.dart';
import '../utils/design_tokens.dart';

class SectionEyebrow extends StatefulWidget {
  final String label;
  final int count;
  final SectionDensity density;

  const SectionEyebrow({
    super.key,
    required this.label,
    required this.count,
    this.density = SectionDensity.relaxed,
  });

  @override
  State<SectionEyebrow> createState() => _SectionEyebrowState();
}

enum SectionDensity { relaxed, moderate, compact }

class _SectionEyebrowState extends State<SectionEyebrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rule;
  late final Animation<double> _label;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppMotion.base);
    _rule = CurvedAnimation(parent: _ctrl, curve: AppMotion.ease);
    _label = CurvedAnimation(parent: _ctrl, curve: AppMotion.ease);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.paperOnGroundSoft
        : AppColors.inkSoft;
    final ruleColor = isDark ? AppColors.ruleOnGround : AppColors.rule;

    final padTop = switch (widget.density) {
      SectionDensity.relaxed => AppSpacing.s8,
      SectionDensity.moderate => AppSpacing.s6,
      SectionDensity.compact => AppSpacing.s4,
    };
    final padBottom = switch (widget.density) {
      SectionDensity.relaxed => AppSpacing.s4,
      SectionDensity.moderate => AppSpacing.s3,
      SectionDensity.compact => AppSpacing.s2,
    };

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s6,
        right: AppSpacing.s6,
        top: padTop,
        bottom: 0,
      ),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: _label.value,
                child: Transform.translate(
                  offset: Offset((-1 + _label.value) * 8, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        widget.label.toUpperCase(),
                        style: AppType.monoEyebrow(color: mutedColor),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: mutedColor.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        '${widget.count} ARTICLES',
                        style: AppType.monoEyebrow(color: mutedColor)
                            .copyWith(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: padBottom),
              // Hairline reveals from left to right.
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: _rule.value,
                  child: Container(
                    height: 0.5,
                    color: ruleColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
