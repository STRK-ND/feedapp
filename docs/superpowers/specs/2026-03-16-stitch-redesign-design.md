# Stitch UI/UX Redesign - Design Document

**Date**: 2026-03-16
**Project**: Curated Feeds - Stitch Design System Implementation
**Status**: Awaiting Approval

## Overview

Implement the Stitch design system across the entire Curated Feeds Flutter app, matching the HTML prototypes exactly. This is a complete visual overhaul focusing on:
- Modern glassmorphism card design
- Purple primary color theme (#bf83fc)
- Lexend typography throughout
- Dark mode first design (#190f23 background)
- Circular action buttons with glow effects

## Design System

### Color Palette

| Token | HEX | Usage |
|-------|-----|-------|
| Primary | `#bf83fc` | Buttons, badges, active states |
| Background Dark | `#190f23` | App background |
| Background Light | `#f7f5f8` | Light mode background |
| Primary/10 | `rgba(191,131,252,0.1)` | Icon backgrounds, chips |
| Primary/5 | `rgba(191,131,252,0.05)` | Card backgrounds |
| White/80 | `rgba(255,255,255,0.8)` | Light overlay |
| Slate-100 | `#f1f5f9` | Light mode surfaces |

### Typography

| Element | Size | Weight | Line Height |
|---------|------|--------|-------------|
| Card Title | 24-30px | Bold (700) | 1.2 |
| Body Text | 14-15px | Medium (500) | 1.5 |
| Category Badge | 10px | Bold (700) | 1 |
| Nav Label | 10px | Bold/Medium | 1 |
| Settings Label | 16px | Medium (500) | 1.4 |
| Caption | 12px | Regular (400) | 1.4 |

**Font Family**: Lexend (Google Fonts)

### Spacing & Shapes

- **Border Radius**: 16px (1rem) default, 24-32px for large cards
- **Card Padding**: 24px internal
- **Button Size**: 56px (large), 40px (small)
- **Icon Container**: 40x40px with 10px radius
- **Aspect Ratios**: 3:4 for main cards, 1:1 for thumbnails

### Shadows & Effects

- **Save Button Glow**: `[0_0_20px_rgba(191,131,252,0.4)]`
- **Card Shadow**: Elevation 8-12 with purple tint
- **Glassmorphism**: `backdrop-blur-xl` on overlays
- **Gradient Overlays**: `from-background-dark/80 via-transparent to-transparent`

## Screen-by-Screen Design

### 1. Feed Swipe Screen (Main Screen)

**Current Issues:**
- Card layout overflows (needs SingleChildScrollView wrapper)
- Old bento card style with glassmorphism borders
- Missing Stitch action buttons (Skip/Save/Share)

**Stitch Design:**

```
┌──────────────────────────────────┐
│ Header                           │
│ [Menu]  Feed Swipe  [Search]     │
├──────────────────────────────────┤
│                                  │
│   ┌──────────────────────────┐   │
│   │  [Full-bleed image]      │   │
│   │  [Gradient overlay]      │   │
│   │                          │   │
│   │  [Tech] [5 min read]     │   │
│   │  Article Title           │   │
│   │  Description text        │   │
│   │                          │   │
│   │  [Read Full Story →]     │   │
│   └──────────────────────────┘   │
│                                  │
│   [Skip]  [♥ Save]  [Share]     │
│                                  │
├──────────────────────────────────┤
│ [Home] [Discover] [Saved] [Set] │
└──────────────────────────────────┘
```

**Key Changes:**
- Card has full-bleed background image (16:9 or 3:4)
- Gradient overlay from bottom (dark to transparent)
- Category badge + read time overlay on image
- Circular action buttons at bottom (skip/save/share)
- Save button has glow effect and is larger (56px)
- Bottom nav with filled icons for active state

### 2. Saved Articles Screen

**Stitch Design:**

```
┌──────────────────────────────────┐
│ [Back]  Saved          [More]    │
├──────────────────────────────────┤
│ Search saved articles...         │
├──────────────────────────────────┤
│ [All] [Tech] [Arch] [Design]...  │
├──────────────────────────────────┤
│ ┌────┬────────────────────────┐  │
│ │    │ Article Title          │  │
│ │Img │ Source • 2 days ago    │  │
│ │    │ [Tech]       [✓]       │  │
│ └────┴────────────────────────┘  │
│ (Repeat for each saved article)  │
├──────────────────────────────────┤
│ [Home] [Discover] [★Saved] [Set]│
└──────────────────────────────────┘
```

**Key Changes:**
- Horizontal list of category filter chips
- List view with thumbnail + text layout
- Bookmark icon shows saved state
- Cards have rounded corners (16px) and subtle background

### 3. Settings Screen

**Stitch Design:**

```
┌──────────────────────────────────┐
│ [←]  Settings          [Search] │
├──────────────────────────────────┤
│                                  │
│ GENERAL                          │
│ ┌──────────────────────────────┐ │
│ │ 🔔 Notifications        →    │ │
│ │    Alerts, sounds, badges    │ │
│ ├──────────────────────────────┤ │
│ │ 🎨 Theme                Dark →│ │
│ ├──────────────────────────────┤ │
│ │ 🌐 Language             En → │ │
│ └──────────────────────────────┘ │
│                                  │
│ PRIVACY & SECURITY               │
│ ┌──────────────────────────────┐ │
│ │ 🔒 Privacy            →      │ │
│ └──────────────────────────────┘ │
│                                  │
│ ABOUT                            │
│ ┌──────────────────────────────┐ │
│ │ ℹ️  About               →      │ │
│ │ 📋 Terms              →      │ │
│ └──────────────────────────────┘ │
└──────────────────────────────────┘
```

**Key Changes:**
- Grouped settings with section headers (uppercase, wide tracking)
- First item in group has larger padding
- Icon containers (40x40) with primary/10 background
- Chevron_right icon for navigation items
- Rounded cards (16px) with primary/5 border

### 4. Article Detail Screen

**Stitch Design:**

```
┌──────────────────────────────────┐
│ [←] Article Detail [🔖] [Share] │
├──────────────────────────────────┤
│                                  │
│ ┌──────────────────────────────┐ │
│ │  [Full-bleed hero image]     │ │
│ │  [Gradient overlay]          │ │
│ └──────────────────────────────┘ │
│                                  │
│ Article Title (Large, Bold)      │
│                                  │
│ ┌────┬────────────────────────┐  │
│ │👤  │ Alex Rivers            │  │
│ │Pic │ Senior Design Analyst  │  │
│ └────┴────────────────────────┘  │
│                                  │
│ Article body text...             │
│                                  │
│ [Quote block with accent left]   │
│                                  │
│ More body text...                │
│                                  │
│ [Tags]                           │
└──────────────────────────────────┘
```

**Key Changes:**
- Large hero image at top with rounded corners
- Author card with circular avatar
- Blockquotes with purple left border
- Tag chips at bottom
- Full typography with proper hierarchy

## Technical Implementation

### Files to Modify

1. **lib/utils/constants.dart**
   - Update color constants to Stitch palette
   - Update AppColors class

2. **lib/providers/theme_provider.dart**
   - Ensure Lexend is primary font
   - Update text themes for Stitch typography

3. **lib/widgets/card_stack.dart**
   - Complete redesign of article cards
   - Full-bleed image with gradient overlay
   - Add action button row (Skip/Save/Share)
   - Fix overflow with proper constraints

4. **lib/widgets/bottom_navigation_bar.dart**
   - Circular active indicator
   - Filled icons for active state
   - Better spacing and typography

5. **lib/screens/settings_screen.dart**
   - Grouped settings layout
   - Icon containers with primary/10
   - Section headers

6. **lib/screens/article_detail_screen.dart**
   - Hero image header
   - Author card
   - Blockquote styling

### Components to Remove (Unwanted)

- Old glassmorphism with white borders
- Vertical card stack (show one at a time like Stitch)
- DMSans font usage (replace with Lexend)
- Complex swipe animations (simplify)
- Source icon badges (replace with category badges)

### New Components Needed

- `StitchActionButton` - Circular button with glow
- `CategoryBadge` - 10px uppercase label
- `SettingsItem` - List tile with icon container
- `GradientOverlay` - Bottom-to-top fade

## Success Criteria

- [ ] All 4 screens match Stitch HTML prototypes visually
- [ ] Colors match exactly (#bf83fc primary, #190f23 dark bg)
- [ ] Typography uses Lexend throughout
- [ ] Cards have proper aspect ratios and shadows
- [ ] No overflow errors on any screen
- [ ] Bottom navigation matches Stitch design
- [ ] Settings screen has grouped layout

## Next Steps

1. Approve this design document
2. Create implementation plan
3. Begin screen-by-screen implementation
4. Test on device for visual fidelity
