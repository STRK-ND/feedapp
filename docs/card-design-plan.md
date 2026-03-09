# Card Design & Layout Options Plan

## Current Implementation Analysis

**Current Design:**
- Swipeable card stack (Tinder-style)
- Large hero image at top (180px height)
- Source badge with colored background
- Title with Playfair Display (26px)
- Description snippet (2 lines max)
- Time stamp badge at bottom
- Layered shadows with source color accent
- Staggered entrance animation (500ms)

**Strengths:** ✅ Clean typography, good visual hierarchy, accessibility (Semantics), reduced motion support
**Improvements:** Could use more visual variety, glass effects, better depth

---

## Design Options

### Option 1: Glassmorphism Cards (Recommended)
**Style:** Modern frosted glass with blur
**Best for:** Premium, elegant feel matching your midnight blue theme

| Element | Current | Glassmorphism |
|---------|---------|---------------|
| Background | Solid white | `bg-white/80` + blur(20px) |
| Border | 1px divider | Subtle white/20 |
| Shadow | Layered | Soft glow effect |
| Category chip | Solid color bg | Frosted glass |
| Image | Rounded 20px | Gradient overlay |

**Implementation:**
```dart
// Card container
Container(
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.7),
    backdropFilter: BackdropFilter.blur(20),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
  ),
)
```

**Pros:** Modern, premium feel, works well with dark mode
**Cons:** Performance on older devices, may need fallback

---

### Option 2: Bento Grid Layout
**Style:** Apple-style modular grid
**Best for:** Dashboard, saved articles view

**Variants:**
- **1x1:** Standard article card (current)
- **2x1:** Featured article (larger image, more text)
- **2x2:** Hero article (full-width, prominent)

**Layout Structure:**
```
┌─────────────────────────────────┐
│  Featured (2x1)                 │
│  ┌─────────────┬───────────────┐│
│  │ Image       │ Title + Desc  ││
│  │             │ + Actions     ││
│  └─────────────┴───────────────┘│
├───────────┬─────────────────────┤
│ 1x1       │ 1x1                │
│ Standard  │ Standard           │
├───────────┴─────────────────────┤
│  Saved Articles Section (2x2)   │
└─────────────────────────────────┘
```

---

### Option 3: Dimensional Layering
**Style:** 3D depth with overlapping elements
**Best for:** Engaging, interactive feel

**Design Elements:**
- Card elevation with 4 shadow levels
- Overlapping image with slight rotation
- Floating action buttons
- Parallax scroll effect

```dart
boxShadow: [
  // Layer 1: Ambient
  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20),
  // Layer 2: Direct
  BoxShadow(color: sourceColor.withValues(alpha: 0.15), blurRadius: 30, offset: Offset(0, 10)),
  // Layer 3: Highlight
  BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 5, offset: Offset(0, -2)),
]
```

---

### Option 4: Editorial Magazine
**Style:** Print-inspired, typography-heavy
**Best for:** Reading-focused experience

**Elements:**
- Large drop cap on first letter
- Pull quotes styled differently
- Byline with author avatar
- Reading time estimate
- Progress indicator
- Section dividers

**Layout:**
```
┌─────────────────────────────────────┐
│ ┌──────┐                            │
│ │ IMG  │  Source • Author • 5 min   │
│ └──────┘  Title (Playfair 28px)     │
│          ─────────────────────────  │
│          "Pull quote styling        │
│          with italic & border"      │
│                                    │
│          Description text...        │
└─────────────────────────────────────┘
```

---

### Option 5: Tactile Digital (Micro-interactions)
**Style:** Bouncy, responsive to touch
**Best for:** Mobile-first, playful brands

**Animations:**
- Press: Scale to 0.95 with squish
- Release: Spring bounce-back (cubic-bezier)
- Swipe: Rotation + velocity-based throw
- Save: Heart pulse animation

```dart
// Tactile press effect
Transform.scale(
  scale: isPressed ? 0.95 : 1.0,
  child: AnimatedContainer(
    duration: Duration(milliseconds: 150),
    curve: Curves.easeOutBack, // Spring effect
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      boxShadow: isPressed
        ? [BoxShadow(color: sourceColor.withValues(alpha: 0.3), blurRadius: 20, offset: Offset(0, 5))]
        : [existingShadow],
    ),
  ),
)
```

---

### Option 6: List View (Alternative Display)
**Style:** Compact, information-dense
**Best for:** Users who want to scan many articles

**Two variants:**
1. **Compact List:** Image left, text right (60px height)
2. **Article List:** Image top, text below (140px height)

```
┌─────────────────────────────────────┐
│ ┌─────┐ Title + Source + Time       │
│ │     │ Description preview...      │
│ │ IMG │                              │
│ │     │ [Save] [Share] [Read] →     │
│ └─────┘                             │
├─────────────────────────────────────┤
│ ┌─────┐ Title + Source + Time       │
│ │ IMG │ Description preview...      │
│ └─────┘                             │
└─────────────────────────────────────┘
```

---

## Recommended Implementation Order

### Phase 1: Quick Wins (Low Effort)
1. **Glassmorphism on category filters** - Add backdrop blur
2. **Enhanced shadows** - Add dimensional layering
3. **Tactile button press** - Scale animation on tap

### Phase 2: Medium Effort
4. **New List View toggle** - Alternative display mode
5. **Hero image transitions** - Fade/scale on load
6. **Empty state illustrations** - Custom graphics

### Phase 3: Higher Effort
7. **Bento grid saved articles** - Grid layout for saved
8. **Editorial card variant** - Magazine-style cards
9. **Parallax scroll effect** - Depth on scroll

---

## Design Tokens to Update

```dart
class AppCardStyles {
  // Border radius
  static const double cardRadius = 24.0;
  static const double imageRadius = 20.0;
  static const double badgeRadius = 12.0;

  // Shadows
  static List<BoxShadow> get cardShadow => [...];
  static List<BoxShadow> get pressedShadow => [...];

  // Glass effect
  static BoxDecoration get glassDecoration => BoxDecoration(
    color: Colors.white.withValues(alpha: 0.7),
    borderRadius: BorderRadius.circular(cardRadius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
  );

  // Animation durations
  static const Duration pressDuration = Duration(milliseconds: 150);
  static const Duration bounceDuration = Duration(milliseconds: 400);
  static const Curve bounceCurve = Curves.easeOutBack;
}
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/utils/constants.dart` | Add AppCardStyles class |
| `lib/widgets/card_stack.dart` | Add glass/glass+ dimensional options |
| `lib/widgets/expanded_article_card.dart` | Add tactile animations |
| `lib/screens/feed_screen.dart` | Add view mode toggle (cards/list) |
| `lib/main.dart` | Add page transition theme |

---

## Acceptance Criteria

- [ ] At least 2 card styles available (current + new)
- [ ] View mode toggle works (cards ↔ list)
- [ ] All animations respect reduced-motion preference
- [ ] Touch targets minimum 44x44px
- [ ] Cards work in both light and dark modes
- [ ] No layout shift during image loading