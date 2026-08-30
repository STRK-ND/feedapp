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
/// The dot at right turns amber when there are unread articles. Tapping
/// it is wired by the parent as the "mark all as read" affordance.
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

/// Masthead pieces. The weekday is intentionally separate so it can wear
/// the italic accent — the one soft moment on an otherwise mono rail.
/// Full form:  *Tuesday* · 08.17 · EDITION Nº 0048
String _weekdayWord(DateTime when) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return weekdays[when.weekday - 1];
}

String _dateStamp(DateTime when) {
  final dd = when.day.toString().padLeft(2, '0');
  final mm = when.month.toString().padLeft(2, '0');
  return '$mm.$dd.${when.year}';
}

class FolioRule extends StatelessWidget {
  final DateTime date;
  final int edition;
  final int articleCount;
  final int unreadCount;
  final bool isPro;
  final VoidCallback? onTapDot;

  const FolioRule({
    super.key,
    required this.date,
    required this.edition,
    required this.articleCount,
    required this.unreadCount,
    this.isPro = false,
    this.onTapDot,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ground = isDark ? AppColors.ground : AppColors.paper;
    final mono = isDark ? AppColors.paperOnGround : AppColors.ink;
    final monoSoft = isDark ? AppColors.paperOnGroundSoft : AppColors.inkSoft;
    final ruleColor = isDark ? AppColors.ruleOnGround : AppColors.rule;
    const accent = AppColors.curation;
    final hasUnread = unreadCount > 0;

    // Full-bleed masthead band: 1px top rule, 0.5px bottom — reads as a
    // paper masthead, not a status bar. Italic weekday is the one soft
    // element against the heavy mono rail.
    return Container(
      decoration: BoxDecoration(
        color: ground,
        border: Border(
          top: BorderSide(color: ruleColor, width: 1),
          bottom: BorderSide(color: ruleColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2 + 2,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final editionStamp =
              'EDITION Nº ${edition.toString().padLeft(4, '0')}';
          final isNarrow = constraints.maxWidth < 360;
          final weekday = isNarrow
              ? _weekdayWord(date)
              : '${_weekdayWord(date)} ·';

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // *Tue* — italic Playfair. The signature soft moment.
              Text(
                weekday,
                style: AppType.displayItalic(
                  color: mono,
                  fontSize: 18,
                ).copyWith(height: 1),
              ),
              const SizedBox(width: AppSpacing.s1 + 2),
              // Mono date + edition.
              Expanded(
                child: Text(
                  '${_dateStamp(date)}  $editionStamp',
                  style: AppType.folioTop(color: monoSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPro) ...[
                const SizedBox(width: AppSpacing.s2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: accent, width: 1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'PRO',
                    style: AppType.folioTop(
                      color: accent,
                    ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.s3),
              // Amber dot = the unread count, made readable. The count
              // rides next to it; no prose ("12 curated · 5 unread").
              if (hasUnread) ...[
                Text('$unreadCount', style: AppType.monoDateline(color: mono)),
                const SizedBox(width: AppSpacing.s1),
              ],
              Semantics(
                button: true,
                label: hasUnread
                    ? 'Mark all as read. $unreadCount unread.'
                    : 'No unread.',
                child: GestureDetector(
                  onTap: onTapDot,
                  behavior: HitTestBehavior.opaque,
                  // 40×40 hit area so the tiny dot meets a usable touch
                  // target (spec §10); the visual dot stays 14px.
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: _AnimatedDot(active: hasUnread, color: accent),
                      ),
                    ),
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
    _ctrl = AnimationController(vsync: this, duration: AppMotion.slow);
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
            color: widget.active ? widget.color : idleColor,
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
