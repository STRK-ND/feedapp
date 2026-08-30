/// Onboarding — three-step first-launch flow.
///
/// 1. Pick a room (theme picker with live preview).
/// 2. Reader preferences (font size, line height, datelines).
/// 3. Add a first source (quick-tap from a curated short-list).
///
/// Onboarding can be skipped from any step. Once completed (or skipped),
/// `hasCompletedOnboarding` is set true and the user lands in the main app.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/generated/app_localizations.dart';
import '../di/service_locator.dart';
import '../services/rss_feed_service.dart';
import '../services/settings_service.dart';
import '../utils/design_tokens.dart';
import 'curated_feeds_app.dart';
import '../widgets/folio_rule.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;

  // Step 1
  ThemeMode _theme = ThemeMode.system;

  // Step 2
  double _fontSize = 16;
  double _lineHeight = 1.6;
  bool _monoDatelines = true;

  // Step 3
  final Set<String> _pickedSources = {};

  void _next() {
    HapticFeedback.selectionClick();
    if (_step < 2) {
      _pageController.nextPage(duration: AppMotion.base, curve: AppMotion.ease);
    } else {
      _finish();
    }
  }

  void _back() {
    HapticFeedback.selectionClick();
    if (_step > 0) {
      _pageController.previousPage(
        duration: AppMotion.base,
        curve: AppMotion.ease,
      );
    }
  }

  Future<void> _finish() async {
    final settings = getIt<SettingsService>();
    await settings.setThemeMode(_theme);
    await settings.setReaderFontSize(_fontSize);
    await settings.setReaderLineHeight(_lineHeight);
    await settings.setMonoDatelinesEnabled(_monoDatelines);
    // Narrow the feed only when the user actually picked sources;
    // "CONTINUE WITHOUT" keeps the default (all sources).
    if (_pickedSources.isNotEmpty) {
      await settings.setSubscribedSourceIds(_pickedSources);
    }
    await settings.setHasCompletedOnboarding(true);
    EditionState.current = await settings.getEditionNumber();
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const CuratedFeedsApp(),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: AppMotion.base,
        ),
      ),
    );
  }

  Future<void> _skip() async {
    await getIt<SettingsService>().setHasCompletedOnboarding(true);
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CuratedFeedsApp()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _StepPickRoom(
                    selected: _theme,
                    onChange: (m) => setState(() => _theme = m),
                  ),
                  _StepReaderPrefs(
                    fontSize: _fontSize,
                    lineHeight: _lineHeight,
                    monoDatelines: _monoDatelines,
                    onFont: (v) => setState(() => _fontSize = v),
                    onLine: (v) => setState(() => _lineHeight = v),
                    onMono: (v) => setState(() => _monoDatelines = v),
                  ),
                  _StepAddSources(
                    picked: _pickedSources,
                    onToggle: (id) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_pickedSources.contains(id)) {
                          _pickedSources.remove(id);
                        } else {
                          _pickedSources.add(id);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s4,
        AppSpacing.s4,
        0,
      ),
      child: Row(
        children: [
          _StepDots(step: _step, total: 3),
          const Spacer(),
          TextButton(
            onPressed: _skip,
            child: Text(
              'SKIP',
              style: AppType.monoEyebrow(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ).copyWith(letterSpacing: 1.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        0,
        AppSpacing.s6,
        AppSpacing.s6,
      ),
      child: Row(
        children: [
          if (_step > 0)
            TextButton(
              onPressed: _back,
              child: Text(
                'BACK',
                style: AppType.monoEyebrow(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ).copyWith(letterSpacing: 1.0),
              ),
            ),
          const Spacer(),
          FilledButton(
            onPressed: _next,
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
              _step < 2
                  ? AppLocalizations.of(context).obContinueCta
                  : (_pickedSources.isNotEmpty
                        ? AppLocalizations.of(context).obAddAndContinueCta(_pickedSources.length)
                        : AppLocalizations.of(context).obContinueWithoutCta),
              style: AppType.labelLarge(
                color: Colors.white,
              ).copyWith(letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int step;
  final int total;
  const _StepDots({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    // Reserve a fixed slot so the dots don't collapse to zero width on
    // animation transitions.
    return SizedBox(
      height: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(total, (i) {
          final active = i <= step;
          return AnimatedContainer(
            duration: AppMotion.fast,
            margin: const EdgeInsets.only(right: AppSpacing.s2),
            width: active ? 20 : 8,
            height: 4,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

// ===========================================================================
// STEP 1 — Pick a room (theme picker)
// ===========================================================================

class _StepPickRoom extends StatelessWidget {
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChange;

  const _StepPickRoom({required this.selected, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s8,
        AppSpacing.s6,
        AppSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).obStep1Eyebrow, style: AppType.monoEyebrow(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.s3),
          Text(
            AppLocalizations.of(context).obStep1Title,
            style: AppType.displayLarge(color: cs.onSurface).copyWith(height: 1.05),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            AppLocalizations.of(context).obStep1Subtitle,
            style: AppType.bodyLarge(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.s8),
          _RoomSwatch(
            label: AppLocalizations.of(context).roomPaperLabel,
            description: AppLocalizations.of(context).roomPaperDesc,
            mode: ThemeMode.light,
            selected: selected == ThemeMode.light,
            onTap: () => onChange(ThemeMode.light),
          ),
          const SizedBox(height: AppSpacing.s3),
          _RoomSwatch(
            label: AppLocalizations.of(context).roomLamplightLabel,
            description: AppLocalizations.of(context).roomLamplightDesc,
            mode: ThemeMode.dark,
            selected: selected == ThemeMode.dark,
            onTap: () => onChange(ThemeMode.dark),
          ),
          const SizedBox(height: AppSpacing.s3),
          _RoomSwatch(
            label: AppLocalizations.of(context).roomSystemLabel,
            description: AppLocalizations.of(context).roomSystemDesc,
            mode: ThemeMode.system,
            selected: selected == ThemeMode.system,
            onTap: () => onChange(ThemeMode.system),
          ),
        ],
      ),
    );
  }
}

class _RoomSwatch extends StatelessWidget {
  final String label;
  final String description;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _RoomSwatch({
    required this.label,
    required this.description,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkGround = mode == ThemeMode.dark;
    final ground = isDarkGround ? AppColors.ground : AppColors.paper;
    final ink = isDarkGround ? AppColors.paperOnGround : AppColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label. $description',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.ease,
          padding: const EdgeInsets.all(AppSpacing.s5),
          decoration: BoxDecoration(
            color: ground,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : (isDarkGround ? AppColors.ruleOnGround : AppColors.rule),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: AppType.folioTop(
                      color: AppColors.primary,
                    ).copyWith(letterSpacing: 1.2),
                  ),
                  const Spacer(),
                  if (selected)
                    const Icon(
                      Icons.circle,
                      size: 12,
                      color: AppColors.primary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              // Mini poster — sample article headline + dateline.
              Container(
                padding: const EdgeInsets.all(AppSpacing.s4),
                decoration: BoxDecoration(
                  color: isDarkGround
                      ? AppColors.groundElev
                      : AppColors.paperRaised,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: Border.all(
                    color: isDarkGround
                        ? AppColors.ruleOnGround
                        : AppColors.rule,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '07.07 · 14:03',
                      style: AppType.monoDateline(
                        color: isDarkGround
                            ? AppColors.paperOnGroundSoft
                            : AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      AppLocalizations.of(context).sampleHeading,
                      style: AppType.titleLarge(color: ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                description,
                style: AppType.bodyMedium(
                  color: isDarkGround
                      ? AppColors.paperOnGroundSoft
                      : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// STEP 2 — Reader preferences
// ===========================================================================

class _StepReaderPrefs extends StatelessWidget {
  final double fontSize;
  final double lineHeight;
  final bool monoDatelines;
  final ValueChanged<double> onFont;
  final ValueChanged<double> onLine;
  final ValueChanged<bool> onMono;

  const _StepReaderPrefs({
    required this.fontSize,
    required this.lineHeight,
    required this.monoDatelines,
    required this.onFont,
    required this.onLine,
    required this.onMono,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final previewInk = isDark ? AppColors.paperOnGround : AppColors.ink;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s8,
        AppSpacing.s6,
        AppSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).obStep2Eyebrow, style: AppType.monoEyebrow(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.s3),
          Text(
            AppLocalizations.of(context).obStep2Title,
            style: AppType.displayLarge(color: cs.onSurface).copyWith(height: 1.05),
          ),
          const SizedBox(height: AppSpacing.s6),
          // Live preview — a mode-matched card (dark groundElev / light raised),
          // not a fixed white box that floats on dark.
          Container(
            padding: const EdgeInsets.all(AppSpacing.s5),
            decoration: BoxDecoration(
              color: isDark ? AppColors.groundElev : AppColors.paperRaised,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: isDark ? AppColors.ruleOnGround : AppColors.rule,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (monoDatelines)
                  Text(
                    'CURATED · 07.07 · 14:03',
                    style: AppType.monoEyebrow(
                      color: isDark ? AppColors.paperOnGroundSoft : AppColors.inkSoft,
                    ).copyWith(letterSpacing: 0.6),
                  ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  AppLocalizations.of(context).sampleSentence,
                  style: AppType.displayMedium(
                    color: previewInk,
                  ).copyWith(fontSize: fontSize, height: lineHeight),
                ),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  AppLocalizations.of(context).lineHeightExplainer,
                  style: AppType.bodyMedium(
                    color: isDark ? AppColors.paperOnGroundSoft : AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          _SliderRow(
            label: AppLocalizations.of(context).fontSizeLabel,
            value: fontSize,
            min: 14,
            max: 22,
            display: '${fontSize.toStringAsFixed(0)} PT',
            onChange: onFont,
          ),
          const SizedBox(height: AppSpacing.s4),
          _SliderRow(
            label: AppLocalizations.of(context).lineHeightLabel,
            value: lineHeight,
            min: 1.4,
            max: 1.8,
            display: lineHeight.toStringAsFixed(2),
            onChange: onLine,
          ),
          const SizedBox(height: AppSpacing.s4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              AppLocalizations.of(context).typewriterDatelinesLabel,
              style: AppType.monoEyebrow(color: cs.onSurfaceVariant),
            ),
            subtitle: Text(
              AppLocalizations.of(context).typewriterDatelinesDesc,
              style: AppType.bodyMedium(color: cs.onSurface),
            ),
            value: monoDatelines,
            onChanged: onMono,
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChange;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppType.monoEyebrow(
                color: cs.onSurfaceVariant,
              ).copyWith(letterSpacing: 0.8),
            ),
            const Spacer(),
            Text(
              display,
              style: AppType.monoDateline(
                color: AppColors.primary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.primary.withValues(alpha: 0.2),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChange,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// STEP 3 — Add a first source
// ===========================================================================

class _StepAddSources extends StatelessWidget {
  final Set<String> picked;
  final ValueChanged<String> onToggle;

  const _StepAddSources({required this.picked, required this.onToggle});

  // Curated first-issue picks — real IDs only, resolved through the
  // source registry so name/category/icon stay in sync.
  static const _sourceIds = [
    'verge',
    'wired',
    'bbc',
    'newscientist',
    'skysports',
    'variety',
    'arstechnica',
    'techcrunch',
    'ign',
    'nasa',
  ];
  List<({String id, String name, String category, IconData icon})>
  get _sources => getIt<RssFeedService>()
      .sources
      .where((s) => _sourceIds.contains(s.id))
      .map((s) => (id: s.id, name: s.name, category: s.category, icon: s.icon))
      .toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s8,
        AppSpacing.s6,
        AppSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PICK A FIRST SOURCE', style: AppType.monoEyebrow(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.s3),
          Text(
            AppLocalizations.of(context).obStep3Title,
            style: AppType.displayLarge(color: cs.onSurface).copyWith(height: 1.05),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            AppLocalizations.of(context).obStep3Subtitle,
            style: AppType.bodyLarge(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.s6),
          for (final s in _sources) ...[
            _SourceRow(
              id: s.id,
              name: s.name,
              category: s.category,
              icon: s.icon,
              picked: picked.contains(s.id),
              onTap: () => onToggle(s.id),
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final String id;
  final String name;
  final String category;
  final IconData icon;
  final bool picked;
  final VoidCallback onTap;

  const _SourceRow({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.picked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ruleColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.ruleOnGround
            : AppColors.rule;
    return Semantics(
      button: true,
      selected: picked,
      label: '$name. $category.',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s4,
          ),
          decoration: BoxDecoration(
            color: picked
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(
              color: picked ? AppColors.primary : ruleColor,
              width: picked ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: cs.onSurfaceVariant, size: 22),
              const SizedBox(width: AppSpacing.s4),
              Text(name, style: AppType.titleMedium(color: cs.onSurface)),
              const Spacer(),
              Text(
                category,
                style: AppType.monoEyebrow(
                  color: cs.onSurfaceVariant,
                ).copyWith(letterSpacing: 0.6),
              ),
              const SizedBox(width: AppSpacing.s3),
              AnimatedContainer(
                duration: AppMotion.fast,
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: picked ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: picked ? AppColors.primary : ruleColor,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: picked
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
