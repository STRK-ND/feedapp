# Stitch UI/UX Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign all app screens to match Stitch design system with purple primary color, full-bleed image cards, and modern glassmorphism

**Architecture:** Update constants first, then theme provider, then widgets screen by screen. Keep existing business logic, only change UI layer.

**Tech Stack:** Flutter, Google Fonts (Lexend), Material Design with custom styling

---

## File Structure Changes

### Files to Create:
- `lib/widgets/stitch/stitch_action_buttons.dart` - Skip/Save/Share button row
- `lib/widgets/stitch/category_badge.dart` - 10px uppercase labels
- `lib/widgets/stitch/gradient_overlay.dart` - Bottom-to-top gradient for images

### Files to Modify:
- `lib/utils/constants.dart` - Update color constants to Stitch palette
- `lib/providers/theme_provider.dart` - Lexend font throughout
- `lib/widgets/card_stack.dart` - Full redesign with Stitch cards
- `lib/widgets/bottom_navigation_bar.dart` - New nav style
- `lib/screens/settings_screen.dart` - Grouped settings layout
- `lib/screens/article_detail_screen.dart` - Hero image layout

### Files to Remove/Unreference:
- Old DMSans font references (not used in Stitch)
- Glassmorphism with white borders (replaced with gradient overlays)

---

## Chunk 1: Foundation (Colors & Typography)

### Task 1.1: Update AppColors

**Files:**
- Modify: `lib/utils/constants.dart`
- Test: Visual verification in app

- [ ] **Step 1: Update primary colors**
```dart
// In lib/utils/constants.dart, AppColors class:
static const Color primary = Color(0xFFBF83FC);  // Purple
static const Color backgroundDark = Color(0xFF190F23);  // Deep purple
static const Color backgroundLight = Color(0xFFF7F5F8);
static const Color primary10 = Color(0x1ABF83FC);  // 10% opacity
static const Color primary5 = Color(0x0DBF83FC);  // 5% opacity
```

- [ ] **Step 2: Update card styles**
```dart
// Add to AppCardStyles:
static const double cardRadius = 24.0;
static const double chipRadius = 16.0;
static const double buttonRadius = 999.0;  // Full circular
```

- [ ] **Step 3: Run flutter build**
```bash
/c/flutter/bin/flutter clean
/c/flutter/bin/flutter build apk --debug
```
Expected: Build completes without errors

- [ ] **Step 4: Commit**
```bash
git add lib/utils/constants.dart
git commit -m "feat: update color palette to Stitch design system"
```

### Task 1.2: Update Theme Provider for Lexend

**Files:**
- Modify: `lib/providers/theme_provider.dart`

- [ ] **Step 1: Replace all TextStyle references**
Remove: `GoogleFonts.dmSans`
Replace with: `GoogleFonts.lexend`

- [ ] **Step 2: Update typography scale**
```dart
TextTheme customTextTheme = TextTheme(
  headlineLarge: GoogleFonts.lexend(fontSize: 30, fontWeight: FontWeight.w700),
  headlineMedium: GoogleFonts.lexend(fontSize: 24, fontWeight: FontWeight.w700),
  titleLarge: GoogleFonts.lexend(fontSize: 20, fontWeight: FontWeight.w600),
  bodyLarge: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w500),
  bodyMedium: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w500),
  labelLarge: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w700),
  labelSmall: GoogleFonts.lexend(fontSize: 10, fontWeight: FontWeight.w700),
);
```

- [ ] **Step 3: Build and verify**
```bash
/c/flutter/bin/flutter build apk --debug
```

- [ ] **Step 4: Commit**
```bash
git add lib/providers/theme_provider.dart
git commit -m "feat: use Lexend font throughout"
```

---

## Chunk 2: Card Stack Redesign

### Task 2.1: Create Stitch Action Buttons Component

**Files:**
- Create: `lib/widgets/stitch/stitch_action_buttons.dart`

- [ ] **Step 1: Create file structure**
```bash
mkdir -p lib/widgets/stitch
```

- [ ] **Step 2: Write action buttons widget**
```dart
import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class StitchActionButtons extends StatelessWidget {
  final VoidCallback onSkip;
  final VoidCallback onSave;
  final VoidCallback onShare;

  const StitchActionButtons({
    super.key,
    required this.onSkip,
    required this.onSave,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Skip button
          _ActionButton(
            icon: Icons.close,
            label: 'Skip',
            color: AppColors.textTertiary,
            backgroundColor: AppColors.background,
            onTap: onSkip,
            size: 56,
          ),
          // Save button (larger with glow)
          _SaveButton(onTap: onSave),
          // Share button
          _ActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            color: AppColors.textTertiary,
            backgroundColor: AppColors.background,
            onTap: onShare,
            size: 56,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;
  final double size;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: size * 0.35),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SaveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite,
              color: AppColors.backgroundDark,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Save',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Commit**
```bash
git add lib/widgets/stitch/stitch_action_buttons.dart
git commit -m "feat: add Stitch action buttons component"
```

### Task 2.2: Create Category Badge Component

**Files:**
- Create: `lib/widgets/stitch/category_badge.dart`

- [ ] **Step 1: Write category badge**
```dart
import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class CategoryBadge extends StatelessWidget {
  final String category;
  final Color? backgroundColor;
  final Color? textColor;

  const CategoryBadge({
    super.key,
    required this.category,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          color: textColor ?? AppColors.backgroundDark,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**
```bash
git add lib/widgets/stitch/category_badge.dart
git commit -m "feat: add Stitch category badge component"
```

### Task 2.3: Redesign Card Stack

**Files:**
- Modify: `lib/widgets/card_stack.dart`

- [ ] **Step 1: Update imports**
```dart
import 'stitch/stitch_action_buttons.dart';
import 'stitch/category_badge.dart';
```

- [ ] **Step 2: Replace _buildArticleCard card design**
```dart
Widget _buildArticleCard(Article article, int index, bool isFront) {
  final sourceColor = getIt<RssFeedService>().getSourceColorFromArticle(article);
  final sourceIcon = getIt<RssFeedService>().getSourceIconFromArticle(article);
  final sourceName = article.sourceName.isNotEmpty
      ? article.sourceName
      : (getIt<RssFeedService>().getSourceById(article.sourceId)?.name ?? 'Unknown');
  final sourceCategory = article.category ?? 'Technology';

  return GestureDetector(
    onTap: () {
      if (isFront) {
        widget.onTap(index);
      }
    },
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              if (article.imageUrl != null)
                CachedNetworkImage(
                  imageUrl: article.imageUrl!,
                  fit: BoxFit.cover,
                  cacheManager: AppCacheManager(),
                )
              else
                Container(color: AppColors.primary10),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.backgroundDark,
                      AppColors.backgroundDark.withOpacity(0.6),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 0.8],
                  ),
                ),
              ),

              // Content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Category badges
                      Row(
                        children: [
                          CategoryBadge(category: sourceCategory),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.schedule, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '${ReadTimeCalculator.calculateReadTime(article.description)} min read',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        article.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Text(
                        article.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 24),

                      // Read more button
                      GestureDetector(
                        onTap: () => widget.onTap(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary10,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Read Full Story',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 3: Update build method to add action buttons**
```dart
@override
Widget build(BuildContext context) {
  if (widget.articles.isEmpty) {
    return widget.emptyState;
  }

  final article = widget.articles.first;

  return Column(
    children: [
      Expanded(
        child: SwipeableCard(
          key: ValueKey('card_${article.id}'),
          child: _buildArticleCard(article, 0, true),
          onSwipeRight: () => widget.onSwipeRight(0),
          onSwipeLeft: () => widget.onSwipeLeft(0),
          onTap: () => widget.onTap(0),
        ),
      ),
      StitchActionButtons(
        onSkip: () => widget.onSwipeLeft(0),
        onSave: () => widget.onSwipeRight(0),
        onShare: () => _shareArticle(article),
      ),
    ],
  );
}

void _shareArticle(Article article) {
  // TODO: Implement share functionality
  Share.share(article.link);
}
```

- [ ] **Step 4: Add share import**
```dart
import 'package:share_plus/share_plus.dart';
```

- [ ] **Step 5: Build and test**
```bash
/c/flutter/bin/flutter build apk --debug
```

- [ ] **Step 6: Commit**
```bash
git add lib/widgets/card_stack.dart lib/widgets/stitch/
git commit -m "feat: redesign card stack with Stitch design"
```

---

## Chunk 3: Navigation & Settings

### Task 3.1: Update Bottom Navigation Bar

**Files:**
- Modify: `lib/widgets/bottom_navigation_bar.dart`

- [ ] **Step 1: Update nav item style**
```dart
Widget _buildNavItem(IconData icon, String label, int index) {
  final isSelected = _selectedIndex == index;

  return GestureDetector(
    onTap: () => _onItemTapped(index),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isSelected ? AppColors.primary : AppColors.textTertiary,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textTertiary,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 2: Update container style**
```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.backgroundDark.withOpacity(0.95),
    border: Border(
      top: BorderSide(
        color: AppColors.primary.withOpacity(0.1),
        width: 1,
      ),
    ),
  ),
  // ... rest of implementation
)
```

- [ ] **Step 3: Commit**
```bash
git add lib/widgets/bottom_navigation_bar.dart
git commit -m "feat: update bottom navigation to Stitch style"
```

### Task 3.2: Redesign Settings Screen

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Create settings item widget**
```dart
class SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback onTap;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(
              value!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
      onTap: onTap,
    );
  }
}

class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.primary5,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.05)),
          ),
          child: Column(
            children: _divideTiles(children),
          ),
        ),
      ],
    );
  }

  List<Widget> _divideTiles(List<Widget> tiles) {
    final result = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      result.add(tiles[i]);
      if (i < tiles.length - 1) {
        result.add(Divider(
          height: 1,
          indent: 72,
          color: AppColors.primary.withOpacity(0.05),
        ));
      }
    }
    return result;
  }
}
```

- [ ] **Step 2: Update settings screen layout**
Replace the current ListView with grouped sections using `SettingsSection` and `SettingsItem`.

- [ ] **Step 3: Commit**
```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: redesign settings screen with Stitch grouping"
```

---

## Chunk 4: Article Detail Screen

### Task 4.1: Redesign Article Detail

**Files:**
- Modify: `lib/screens/article_detail_screen.dart`

- [ ] **Step 1: Update header with hero image**
```dart
SliverAppBar(
  expandedHeight: 400,
  pinned: true,
  flexibleSpace: FlexibleSpaceBar(
    background: Stack(
      fit: StackFit.expand,
      children: [
        // Hero image
        CachedNetworkImage(
          imageUrl: article.imageUrl ?? '',
          fit: BoxFit.cover,
        ),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppColors.backgroundDark,
                AppColors.backgroundDark.withOpacity(0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    ),
  ),
)
```

- [ ] **Step 2: Update body styling**
```dart
Padding(
  padding: const EdgeInsets.all(24),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Title
      Text(
        article.title,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 24),

      // Author row
      Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary10,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article.sourceName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${ReadTimeCalculator.calculateReadTime(article.description)} min read',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 24),

      // Article content
      Text(
        article.description,
        style: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  ),
)
```

- [ ] **Step 3: Commit**
```bash
git add lib/screens/article_detail_screen.dart
git commit -m "feat: redesign article detail with hero image layout"
```

---

## Chunk 5: Final Verification

### Task 5.1: Build and Test

- [ ] **Step 1: Full clean build**
```bash
/c/flutter/bin/flutter clean
/c/flutter/bin/flutter build apk --release
```
Expected: Build succeeds

- [ ] **Step 2: Verify no analysis errors**
```bash
/c/flutter/bin/flutter analyze
```
Expected: No issues found

- [ ] **Step 3: Final commit**
```bash
git add .
git commit -m "feat: complete Stitch UI/UX redesign"
```

---

## Summary

| Chunk | Tasks | Deliverable |
|-------|-------|-------------|
| 1 | Colors & Fonts | Stitch color palette + Lexend typography |
| 2 | Card Stack | Full-bleed image cards with action buttons |
| 3 | Navigation & Settings | Bottom nav + grouped settings |
| 4 | Article Detail | Hero image layout |
| 5 | Verification | Working build with no errors |

**Estimated Time:** 2-3 hours
**Priority:** High (user requested only Stitch UI)
**Dependencies:** None (all UI layer changes)
