# Design System — Curated Feeds

## Product Context
- **What this is:** Mobile RSS reader app that aggregates content from ~12 curated sources
- **Who it's for:** People who want a personalized, visually rich reading experience
- **Space/industry:** Content aggregation / news reading apps (Feedly, Flipboard, Apple News)
- **Project type:** Mobile app (Flutter, iOS + Android)

## Aesthetic Direction
- **Direction:** Maximalist-minimal hybrid — frosted glass cards floating above deep purple backgrounds
- **Decoration level:** Intentional — glassmorphism is the signature. Blur + white borders + soft glow shadows
- **Mood:** "Late night reading" — rich, immersive, content-first. Not dark-for-dark's-sake; the glass effect makes it feel dimensional
- **Reference:** The card IS the product. Everything else recedes.

## Typography
- **Display/Hero:** Lexend (Google Fonts) — humanist, warm, modern. Good readability at all sizes. Not overused
- **Body:** Lexend (same as display, consistent system)
- **UI/Labels:** Lexend — unified type family
- **Data/Tables:** Lexend with `tabular-nums` for timestamps
- **Code:** N/A (mobile app)
- **Loading:** Google Fonts CDN via `google_fonts` package
- **Scale:** Modular — hero 48px, headline 32px, title 22px, body 16px, caption 12px

## Color
- **Approach:** Restrained with category accents — purple is the product's face; category colors appear sparingly
- **Primary:** `#BF83FC` — Stitch purple (used for CTAs, save buttons, active states)
- **Primary 10%:** `rgba(191, 131, 252, 0.1)` — subtle tints for backgrounds
- **Background dark:** `#1A1423` — deep purple-black (dark mode default)
- **Background light:** `#F7F5F8` — warm off-white (light mode)
- **Surface:** `#FFFFFF` — card backgrounds in light mode
- **Surface dark:** `#1E1E2E` — card backgrounds in dark mode
- **Text primary:** `#1A1B2E` (light mode) / `#F8F7F4` (dark mode)
- **Text secondary:** `#6B7280` (light) / `#9CA3AF` (dark)
- **Category accents:** Tech `#3B82F6`, News `#DC2626`, Science `#0891B2`, Sports `#059669`, Entertainment `#7C3AED`, Gaming `#8B5CF6`
- **Semantic:** Success `#057A55`, Error `#DC3640`
- **Dark mode strategy:** Reduce saturation 10-20% on surfaces, keep primary accent bright

## Spacing
- **Base unit:** 4px
- **Density:** Comfortable — not cramped, not wasteful
- **Scale:** 2xs(2) xs(4) sm(8) md(16) lg(24) xl(32) 2xl(48) 3xl(64)
- **Card radius:** 24px (primary cards), 20px (images), 16px (badges/chips)
- **Button radius:** Full circular for icon buttons, pill for text buttons

## Layout
- **Approach:** Card-first feed with grid for saved articles
- **Feed:** Single-column swipeable/stacked cards, image-dominant
- **Saved articles:** Bento grid (2 columns, featured articles span 2 columns)
- **Max content width:** 420px (phone-optimized, centered on larger screens)
- **Breakpoints:** Phone (375-428px primary target), tablet (768px+)
- **Navigation:** Bottom nav bar (Feed, Saved, Settings)

## Motion
- **Approach:** Intentional — motion serves comprehension and delight, not decoration
- **Easing:** `easeOutBack` for bounce feel, `ease-out` for entrances, `ease-in` for exits
- **Duration scale:**
  - micro: 150ms — haptics, instant feedback
  - quick: 250ms — button states, toggles
  - standard: 300ms — default UI transitions
  - emphasis: 400-500ms — FAB, card entrances
  - stagger: 600-700ms — feed item cascades
  - shimmer: 1500ms — loading placeholder

## Components

### Article Card (Glassmorphism)
- Frosted glass: `backdrop-filter: blur(20px)`, `background: rgba(255,255,255,0.12)`, `border: 1px solid rgba(255,255,255,0.15)`
- Inner highlight: subtle top-to-bottom gradient for depth
- Shadow: dual-layer — colored glow (`blur: 40, spread: -8`) + neutral depth
- Pressed state: reduced blur, deeper shadow

### Category Chip
- Pill shape: 16px radius
- Active: filled with category color
- Inactive: subtle background, muted text

### Save Button
- 32px circular, primary tint background
- Active (saved): filled primary with white icon
- Hover: scale(1.1), transition 150ms

### Bottom Sheet
- Glass effect: `blur(20px)`, `opacity: 0.95`
- Top radius: 28px
- Shadow: lifted, `blur: 40`, `offset-y: -20`

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-05-15 | Initial design system | Stitch Design System codified — glassmorphism, purple accent, Lexend font, dark-first |
| 2026-05-15 | Typography locked | Lexend chosen over alternatives — humanist warmth, readable, not overused in AI-era design |
| 2026-05-15 | Glassmorphism signature | Dimensional feel differentiates from flat RSS readers; works well on dark backgrounds |
| 2026-05-15 | Category color strategy | Category colors appear as accents only (source badge dot, chip) — not overwhelming the purple brand |