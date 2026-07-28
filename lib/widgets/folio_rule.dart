/// Folio Rule — the signature header of Curated Feeds.
///
/// White-on-paper / paper-on-ground hairline strip above the scrollable
/// feed. A persistent "edition" masthead that gives the app its
/// editorial personality and treats the feed like a daily paper.
///
/// Layout:
///
///   TUESDAY · 08.07.2026      EDITION Nº 0047      •
///
/// The dot at right turns amber when there are unread articles. Tap-to-
/// scroll to first unread is handled by the parent.
///
/// Edition Nº increments on every successful refresh. We expose that via
/// the [EditionNotifier] (in-process) which the FeedScreen drives when a
/// refresh completes.
library;

import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../utils/design_tokens.dart';

/// In-process edition counter. Owned at app root by SplashScreen and
/// propagated down via Provider if available. For simplicity we expose a
/// static field — there's only ever one edition counter per app run.
class EditionState {
  static int current = 1;
  static int unread = 0;

  /// Increment on every successful refresh.
  static int bump() {
    current += 1;
    return current;
  }
}

/// Hydrate the in-memory edition counter from persisted settings.
///
/// Called once at app startup. SettingsService is awaited once and the
/// value is mirrored into EditionState. After this, every successful
/// refresh in FeedScreen calls SettingsService.bumpEditionNumber() which
/// advances both the persisted integer and the in-memory one.
class FolioRuleBootstrap {
  FolioRuleBootstrap._();

  static Future<void> hydrate(SettingsService settings) async {
    EditionState.current = await settings.getEditionNumber();
  }
}

/// Format a date as "TUESDAY · 08.07.2026" — paper-style masthead.
String _formatMasthead(DateTime when) {
  const weekdays = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];
  final wd = weekdays[when.weekday - 1];
  final dd = when.day.toString().padLeft(2, '0');
  final mm = when.month.toString().padLeft(2, '0');
  final yyyy = when.year.toString();
  return '$wd · $dd.$mm.$yyyy';
}

/// Compact masthead that drops the weekday on narrow screens, used when
/// weekday + date + edition all wouldn't fit (sub-360dp).
String _formatMastheadCompact(DateTime when) {
  final dd = when.day.toString().padLeft(2, '0');
  final mm = when.month.toString().padLeft(2, '0');
  final yyyy = when.year.toString();
  return '$dd.$mm.$yyyy';
}

class FolioRule extends StatelessWidget {
  final DateTime date;
  final int edition;
  final int articleCount;
  final int unreadCount;
  final VoidCallback? onTapDot;

  const FolioRule({
    super.key,
    required this.date,
    required this.edition,
    required this.articleCount,
    required this.unreadCount,
    this.onTapDot,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ground = isDark ? AppColors.ground : AppColors.paper;
    final top = isDark ? AppColors.paperOnGroundSoft : AppColors.inkSoft;
    final bottom = isDark ? AppColors.paperOnGround : AppColors.ink;
    final ruleColor = isDark ? AppColors.ruleOnGround : AppColors.rule;
    const accent = AppColors.primary;
    final hasUnread = unreadCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: ground,
        border: Border(
          top: BorderSide(color: ruleColor, width: 0.5),
          bottom: BorderSide(color: ruleColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      // LayoutBuilder so we can swap to a compact masthead on narrow
      // screens and keep EDITION Nº + dot from being squeezed off —
      // turtling the layout when needed beats truncating or wrapping.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  isNarrow
                      ? _formatMastheadCompact(date)
                      : _formatMasthead(date),
                  style: AppType.folioTop(color: top).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                'EDITION  ${edition.toString().padLeft(4, '0')}',
                style: AppType.folioTop(color: bottom),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(
                '$articleCount curated',
                style: AppType.folioTop(color: top).copyWith(
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Semantics(
                button: true,
                label: hasUnread
                    ? 'Jump to first unread. $unreadCount unread.'
                    : 'No unread.',
                child: GestureDetector(
                  onTap: onTapDot,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: _AnimatedDot(active: hasUnread, color: accent),
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

/// Tiny dot — amber when unread present, paper when none.
/// Pulses once on appearance to draw the eye to "there is something to read".
class _AnimatedDot extends StatefulWidget {
  final bool active;
  final Color color;

  const _AnimatedDot({required this.active, required this.color});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    if (widget.active) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _ctrl.forward(from: 0);
    } else if (!widget.active && oldWidget.active) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idleColor = isDark
        ? AppColors.paperOnGroundFaint
        : AppColors.inkFaint;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final pulse = Curves.easeOutCubic.transform(_ctrl.value);
        return Container(
          width: 10 + pulse * 4,
          height: 10 + pulse * 4,
          decoration: BoxDecoration(
            color: widget.active
                ? widget.color
                : idleColor,
            shape: BoxShape.circle,
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4 * pulse),
                      blurRadius: 12 * pulse,
                      spreadRadius: 1 * pulse,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
