/// Onboarding — three-step first-launch flow.
///
/// 1. Pick a room (theme picker with live preview).
/// 2. Reader preferences (font size, line height, datelines).
/// 3. Add a first source (quick-tap from a curated short-list).
///
/// Onboarding can be skipped from any step. Once completed (or skipped),
/// `hasCompletedOnboarding` is set true and the user lands in the main app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../di/service_locator.dart';
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
      _pageController.nextPage(
        duration: AppMotion.base,
        curve: AppMotion.ease,
      );
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
    await settings.setHasCompletedOnboarding(true);
    EditionState.current = await settings.getEditionNumber();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CuratedFeedsApp(),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: AppMotion.base,
      ),
    );
  }

  Future<void> _skip() async {
    await getIt<SettingsService>().setHasCompletedOnboarding(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CuratedFeedsApp()),
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
          AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, 0),
      child: Row(
        children: [
          _StepDots(step: _step, total: 3),
          const Spacer(),
          TextButton(
            onPressed: _skip,
            child: Text(
              'SKIP',
              style: AppType.monoEyebrow(
                color: AppColors.inkSoft,
              ).copyWith(letterSpacing: 1.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final canContinue = _step != 2 || _pickedSources.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s6, 0, AppSpacing.s6, AppSpacing.s6),
      child: Row(
        children: [
          if (_step > 0)
            TextButton(
              onPressed: _back,
              child: Text(
                'BACK',
                style: AppType.monoEyebrow(
                  color: AppColors.inkSoft,
                ).copyWith(letterSpacing: 1.0),
              ),
            ),
          const Spacer(),
          FilledButton(
            onPressed: canContinue ? _next : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: Text(
              _step == 2
                  ? (_pickedSources.isNotEmpty
                      ? 'ADD ${_pickedSources.length}  ·  CONTINUE'
                      : 'PICK ONE TO CONTINUE')
                  : 'CONTINUE',
              style: AppType.labelLarge(color: Colors.white)
                  .copyWith(letterSpacing: 1.2),
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
    return Row(
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s6, AppSpacing.s8, AppSpacing.s6, AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PICK A ROOM',
            style: AppType.monoEyebrow(color: AppColors.inkSoft),
          ),
          SizedBox(height: AppSpacing.s3),
          Text(
            'How should\nthis feel?',
            style: AppType.displayLarge(color: AppColors.ink)
                .copyWith(height: 1.05),
          ),
          SizedBox(height: AppSpacing.s4),
          Text(
            'Three rooms. Pick the one that\nmakes you want to settle in.',
            style: AppType.bodyLarge(color: AppColors.inkSoft),
          ),
          SizedBox(height: AppSpacing.s8),
          _RoomSwatch(
            label: 'PAPER',
            description: 'Daytime. Bright. Off-white stock.',
            mode: ThemeMode.light,
            selected: selected == ThemeMode.light,
            onTap: () => onChange(ThemeMode.light),
          ),
          SizedBox(height: AppSpacing.s3),
          _RoomSwatch(
            label: 'LAMPLIGHT',
            description: 'After dark. Warm amber. The default.',
            mode: ThemeMode.dark,
            selected: selected == ThemeMode.dark,
            onTap: () => onChange(ThemeMode.dark),
          ),
          SizedBox(height: AppSpacing.s3),
          _RoomSwatch(
            label: 'FOLLOW YOUR PHONE',
            description: 'Switches with the system.',
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
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: AppType.folioTop(color: AppColors.primary)
                        .copyWith(letterSpacing: 1.2),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.circle, size: 12, color: AppColors.primary),
                ],
              ),
              SizedBox(height: AppSpacing.s4),
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
                              : AppColors.inkSoft),
                    ),
                    SizedBox(height: AppSpacing.s2),
                    Text(
                      'A heading that earns\nthe reader.',
                      style: AppType.titleLarge(color: ink),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.s3),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s6, AppSpacing.s8, AppSpacing.s6, AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TUNE THE READING',
            style: AppType.monoEyebrow(color: AppColors.inkSoft),
          ),
          SizedBox(height: AppSpacing.s3),
          Text(
            'Make it\ncomfortable.',
            style: AppType.displayLarge(color: AppColors.ink)
                .copyWith(height: 1.05),
          ),
          SizedBox(height: AppSpacing.s6),
          // Live preview
          Container(
            padding: const EdgeInsets.all(AppSpacing.s5),
            decoration: BoxDecoration(
              color: AppColors.paperRaised,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.rule),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (monoDatelines)
                  Text(
                    'CURATED · 07.07 · 14:03',
                    style: AppType.monoEyebrow(color: AppColors.inkSoft)
                        .copyWith(letterSpacing: 0.6),
                  ),
                SizedBox(height: AppSpacing.s2),
                Text(
                  'How a sentence reads at this size.',
                  style: AppType.displayMedium(color: AppColors.ink)
                      .copyWith(fontSize: fontSize, height: lineHeight),
                ),
                SizedBox(height: AppSpacing.s3),
                Text(
                  'Line-height is the breath between lines. Wider is calmer; tighter accelerates.',
                  style: AppType.bodyMedium(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.s6),
          _SliderRow(
            label: 'FONT SIZE',
            value: fontSize,
            min: 14,
            max: 22,
            display: '${fontSize.toStringAsFixed(0)} PT',
            onChange: onFont,
          ),
          SizedBox(height: AppSpacing.s4),
          _SliderRow(
            label: 'LINE HEIGHT',
            value: lineHeight,
            min: 1.4,
            max: 1.8,
            display: lineHeight.toStringAsFixed(2),
            onChange: onLine,
          ),
          SizedBox(height: AppSpacing.s4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'TYPEWRITER DATELINES',
              style: AppType.monoEyebrow(color: AppColors.inkSoft),
            ),
            subtitle: Text(
              'Show dates and counts in JetBrains Mono.',
              style: AppType.bodyMedium(color: AppColors.ink),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: AppType.monoEyebrow(color: AppColors.inkSoft)
                    .copyWith(letterSpacing: 0.8)),
            const Spacer(),
            Text(display,
                style: AppType.monoDateline(color: AppColors.primary)
                    .copyWith(fontWeight: FontWeight.w600)),
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

  static const _sources = [
    ('the-verge', 'The Verge', 'TECH', Icons.privacy_tip_outlined),
    ('hacker-news', 'Hacker News', 'TECH', Icons.terminal),
    ('bbc', 'BBC News', 'NEWS', Icons.public),
    ('reuters', 'Reuters', 'NEWS', Icons.gavel),
    ('ars-technica', 'Ars Technica', 'TECH', Icons.memory),
    ('aeon', 'Aeon', 'ESSAYS', Icons.menu_book_outlined),
    ('lrb', 'LRB Blog', 'ESSAYS', Icons.book),
    ('fivethirtyeight', 'FiveThirtyEight', 'POLITICS', Icons.bar_chart),
    ('the-browser', 'The Browser', 'DAILY DIGEST', Icons.language),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s6, AppSpacing.s8, AppSpacing.s6, AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PICK A FIRST SOURCE',
            style: AppType.monoEyebrow(color: AppColors.inkSoft),
          ),
          SizedBox(height: AppSpacing.s3),
          Text(
            'Start with one\nor twenty.',
            style: AppType.displayLarge(color: AppColors.ink)
                .copyWith(height: 1.05),
          ),
          SizedBox(height: AppSpacing.s4),
          Text(
            'These are first-issue picks. You can change them any time from Settings.',
            style: AppType.bodyLarge(color: AppColors.inkSoft),
          ),
          SizedBox(height: AppSpacing.s6),
          for (final s in _sources) ...[
            _SourceRow(
              id: s.$1,
              name: s.$2,
              category: s.$3,
              icon: s.$4,
              picked: picked.contains(s.$1),
              onTap: () => onToggle(s.$1),
            ),
            SizedBox(height: AppSpacing.s2),
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
              color: picked
                  ? AppColors.primary
                  : AppColors.rule,
              width: picked ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.inkSoft, size: 22),
              SizedBox(width: AppSpacing.s4),
              Text(name, style: AppType.titleMedium(color: AppColors.ink)),
              const Spacer(),
              Text(
                category,
                style: AppType.monoEyebrow(color: AppColors.inkSoft)
                    .copyWith(letterSpacing: 0.6),
              ),
              SizedBox(width: AppSpacing.s3),
              AnimatedContainer(
                duration: AppMotion.fast,
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: picked ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: picked ? AppColors.primary : AppColors.rule,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: picked
                    ? const Icon(Icons.check,
                        size: 12, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
