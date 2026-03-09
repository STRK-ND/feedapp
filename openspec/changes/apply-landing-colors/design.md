## Context

The Flutter app currently uses a cream/white theme with blue primary colors. The landing page uses a dark, elegant indigo-purple gradient theme. This design document outlines how to apply the landing page colors to the Flutter app.

## Goals / Non-Goals

**Goals:**
- Apply the landing page's dark theme to the Flutter app
- Ensure color consistency across the app (cards, text, surfaces, accents)
- Maintain readability and accessibility with proper contrast ratios

**Non-Goals:**
- No layout changes - only color updates
- No dark mode toggle - this is the permanent theme
- No changes to text styling beyond colors

## Decisions

1. **Color System**: Use the landing page CSS variables as the source of truth
   - Primary: #1a1b4d, #2d2f73, #4a3b5c (indigo-purple gradient)
   - Accent: #ff6b9d (coral pink)
   - Background: #0d0e1a, #14162b (dark)
   - Surface: rgba(255, 255, 255, 0.03) with transparency

2. **Implementation**: Update AppColors class in constants.dart
   - Keep semantic naming (primary, accent, surface, text)
   - Add gradients for relevant UI elements
   - Preserve category colors for feature distinction

3. **Text Contrast**: Dark backgrounds require light text
   - Primary text: #f8fafc (off-white)
   - Secondary text: #94a3b8 (muted gray)
   - Tertiary text: #64748b (dark gray)

## Risks / Trade-offs

- [Risk] Some UI elements may not have proper contrast → [Mitigation] Test all screens after implementation
- [Risk] Images in cards may not look good on dark background → [Mitigation] Add subtle image overlay or tint

## Migration Plan

1. Update AppColors in lib/utils/constants.dart
2. Update the Material theme configuration if needed
3. Test all screens (Feed, Article Detail, etc.)
4. Verify visual consistency with landing page