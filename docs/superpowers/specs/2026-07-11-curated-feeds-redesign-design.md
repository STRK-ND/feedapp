# Curated Feeds — Frontend Design

> Distinctive UI/UX redesign of `myapp` ("Curated Feeds"), an RSS reader for
> people who still curate what they read. Subject, audience, and job-to-be-done
> are anchored before any visual decision is made.

---

## 1. Subject vs. AI defaults — why this design is not 3 templates

AI-generated design clusters around:

1. Cream `#F4F1EA` + serif display + terracotta.
2. Near-black + acid-green / vermilion.
3. Broadsheet hairline rules + zero radius + dense columns.

**Curated Feeds already has direction 3 (editorial).** Rather than swap directions
(which would erase the existing personality) we deepen it with one specific move
nobody else uses: **the Folio Rule** — a persistent masthead bar that encodes
date, edition number, and curated count in a typewriter monospace, treating the
feed like a daily paper. Combined with **time-grouped sections** where the
layout itself encodes how recent the article is, this is the visual signature
that distinguishes it from Reeder, NetNewsWire, Readwise Reader, Matter,
Feedly, and Inoreader.

**Time-grouped sections** (Today / Yesterday / Earlier) replace category
chips as the primary way to skim the feed. Each group uses slightly different
vertical density and leading — Today breathes, Yesterday is moderate, Earlier
compacts. This is information-as-typography: layout itself tells you what's
fresh.

---

## 2. The brief, pinned

| Field | Value |
|---|---|
| **Subject** | A reading room for people who still curate what they read. |
| **Audience** | Power readers, journalists, researchers, knowledge workers tired of algorithmic feeds. 25–45, on Android primarily, urban, time-poor but reading-rich. |
| **Single job per page** | Feed → triage (swipe / scroll, save or kill). Saved → re-find a saved piece. Settings → tune the room. |
| **Tone** | Calmer than Apple News. Less corporate than Feedly. Less austere than NetNewsWire. More curious than Pocket. Treats reading as a craft, not a slot machine. |
| **Voice** | Editorial, not promotional. Active verbs. Never apologetic. Inline direction on empty/error states. |
| **Anti-patterns we avoid** | "Top stories for you", social proof, urgency, infinite scroll-by-default, dark-pattern save prompts. |

---

## 3. Identity tokens

These live in `lib/utils/design_tokens.dart` (new) and are referenced by
every screen. The visual truth is in code, not Notion.

### 3.1 Palette — refined, not replaced

Light mode (`#F7F5F8` cream paper) and dark mode (`#0E0814` deeper than current
`#190F23`) are kept. Added: **Sepia** (reader mode) and **E-Ink** (OLED-friendly).

| Token | Hex | Role |
|---|---|---|
| `--primary` | `#C4944E` | Warm amber. The brand color, used at 1 accent per screen max. |
| `--primary-muted` | `rgba(196,148,78,0.15)` | Amber washes for chips/containers. |
| `--primary-faint` | `rgba(196,148,78,0.06)` | Hover surfaces over paper. |
| `--paper` | `#F7F5F8` | Light surface — "off-white paper stock", not pure white. |
| `--paper-raised` | `#FFFFFF` | Cards / sheets over paper. |
| `--ink` | `#1A1B2E` | Deep charcoal-navy text on paper. |
| `--ink-soft` | `#6B7280` | Captions, datelines, PMs. |
| `--ink-faint` | `#9CA3AF` | Disabled, placeholders. |
| `--rule` | `#E5E7EB` | Hairline dividers. |
| `--ground` | `#0E0814` | Dark mode background — deeper than `#190F23`. |
| `--ground-elev` | `#1A1423` | Elevated surface in dark (sheets). |
| `--paper-on-ground` | `#F8F7F4` | Off-warm white text in dark mode. |
| `--rule-on-ground` | `#27212E` | Hairlines on dark. |
| **Sepia reader** | `#F4ECD8` / `#3E2C1C` / `#8C6E45` | Reader theme 3 — paperback covers and "afternoon coffee" feel. |
| **E-Ink reader** | `#000000` / `#E8E2D9` / `#C4944E` interactive only | Reader theme 4 — OLED-friendly maximum contrast. |
| Category accents | (kept from `AppColors`) | Per-category tint: Tech `#3B82F6`, News `#DC2626`, Science `#0891B2`, Sports `#059669`, Entertainment `#7C3AED`, Gaming `#8B5CF6`. These are reused **only inside the reader's source badge**, not as page chrome. |

### 3.2 Type — same voice, third member

Already using Playfair Display + DM Sans. **Adding JetBrains Mono** for metadata:
edition numbers, datelines, timestamps, unread counts in app bar. Three roles,
three voices.

| Role | Used for | Why |
|---|---|---|
| **Display — Playfair Display** | App titles (Settings, Saved, Sources), article titles in feed | Editorial character; not for body or labels |
| **Body — DM Sans** | All running text, setting labels, button text | Calm, screen-tuned, good at small sizes |
| **Utility — JetBrains Mono** | Folio Rule date, edition Nº, dateline "08/12 · 14:03", unread badge pill, section eyebrows (e.g. `TODAY — 14 ARTICLES`) | Typewriter feel: signals "this is metadata, not content" |

Weights used:
- Playfair Display: 600 (titles), 700 (display headings). Never 400 in body.
- DM Sans: 400 (body), 500 (labels), 700 (button text). Never bold for emphasis only.
- JetBrains Mono: 500 with letter-spacing 0.05em + uppercase 11px for eyebrows; 400 regular case for numeric datelines.

Type scale (mobile, 360dp reference):
- `displayLarge` 32 / Playfair 700 / -0.5 — empty states, "No saved articles"
- `displayMedium` 28 / Playfair 700 / -0.4 — article titles in expanded reader
- `headlineSmall` 22 / Playfair 700 / -0.3 — screen titles ("Saved")
- `titleLarge` 18 / Playfair 600 — article titles on cards
- `titleMedium` 16 / DM Sans 600 / 0.0 — settings row titles
- `bodyLarge` 16 / DM Sans 400 / 1.55 — article body text in reader
- `bodyMedium` 14 / DM Sans 400 / 1.5 — secondary body
- `labelLarge` 13 / DM Sans 600 — buttons, primary actions
- `labelMedium` 12 / DM Sans 500 / +0.4 ls — section eyebrows below tablet
- `monoEyebrow` 11 / JetBrains Mono 500 / +0.8 ls uppercase — TODAY, YESTERDAY, EARLIER
- `monoDateline` 12 / JetBrains Mono 400 — "08/12 · 14:03"

### 3.3 Layout

```
spacing-1   = 4px    — chip inset
spacing-2   = 8px    — within-card
spacing-3   = 12px   — row gap
spacing-4   = 16px   — section padding
spacing-5   = 20px   — between-card
spacing-6   = 24px   — gutter
spacing-8   = 32px   — between-section
spacing-12  = 48px   — inter-block
spacing-16  = 64px   — page hero / empty state
```

Radius: `8 (chips)`, `14 (buttons)`, `20 (cards, sheets)`, `28 (sheets top)` —
all from the existing `AppCardStyles`, kept. Reader art is set in a 22px
container with 64ch measure max.

### 3.4 Motion

| Token | Value | Use |
|---|---|---|
| `instant` | 80ms | Color/scale micro-changes on press |
| `fast` | 180ms | Chip toggle, switch flip |
| `base` | 240ms | Card entrance, page transitions |
| `slow` | 360ms | Bottom sheet spring, splash fade |
| `ease` | `cubic-bezier(0.32, 0.72, 0, 1)` | All UI motion except where noted |
| `spring` | `Curves.easeOutBack` w/ 1.05 overshoot | Curved nav indicator, button press |

Reduced motion (`MediaQuery.disableAnimations`): halve durations, fade-only,
no overshoot. Already honored in `GrainOverlay` / splash.

### 3.5 Surfaces — the rules

- Cards: `20px` radius, `1px` border `outlineVariant @ 40%`, soft bottom shadow `8px / 20%`.
- Sheets: top radius `28px`, `primary @ 10%` glow shadow.
- Hairlines: 1px, never 2px. Always `--outlineVariant`.
- Buttons (primary): pill `border-radius: 14`, `faint-on-primary` glow.
- Chips: `8px` radius, `1px` border, `faint` background, mono text.

---

## 4. The Folio Rule — signature element

A persistent header, **above the scrollable content but below the system
status bar and above any filter chips**. It is the screen's masthead, presented
as a thin horizontal strip **with a 1px hairline above and below**.

```
┌─────────────────────────────────────────────────────────┐
│  TUESDAY · 08.07.2026              EDITION Nº 0047      │ ← mono 11 caps
│  47 articles · 12 unread                       ·       │ ← DM Sans 13
└─────────────────────────────────────────────────────────┘
```

Implementation: `lib/widgets/folio_rule.dart`. Replaces the colorful gradient
and inner TextField of the existing AppBar area. On dark mode, it's a dark
ground with paper-on-ground text and amber overline on the date token. On
light mode, paper rule line with ink text and amber overline.

**What makes it distinctive:** Edition Nº **increments on every successful
refresh**, not every day. Curated count shows total articles *in view
right now*. The dot at right is interactive — when one or more articles are
unread, it's amber, otherwise paper-on-ground at 30%. Tap = scroll to first
unread.

**Editorial decision:** Edition Nº implies *back-issues*. First launch
starts at 0001. Each successful refresh and pull-to-refresh will increment.
Persisted in `SharedPreferences` via `SettingsService`. This makes a soft
gamification loop *visible as typography*, not badges.

---

## 5. Time-grouped sections (Feed)

Today the feed shows one card stack at a time — one article per screen, swipe
to triage. **Keep that as the primary action** (it's the strongest UX in the
app), but expand support for a continuous scroll mode (vertical list
view) using:

```
┌─────────────────────────────────────────┐
│  TUESDAY · 08.07.2026  EDITION Nº 0047  │ ← Folio Rule
└─────────────────────────────────────────┘

TODAY · 14 ARTICLES                       ← mono eyebrow
─────────────────────────────────         ← hairline
┌──────────────────────┐
│ Tech · The Verge     │
│ Quietly excellent    │
│ headline goes here … │
│ 08/12 · 14:03        │ ← mono dateline
└──────────────────────┘

YESTERDAY · 06 ARTICLES                   ← mono eyebrow
─────────────────────────────────
…

EARLIER · 27 ARTICLES                     ← mono eyebrow (compact)
─────────────────────────────────
…
```

Core change: replace category-chip top filter with a **view-mode toggle in the
appbar** (Stack Card vs. Continuous Scroll), and in continuous scroll add the
section grouping. Card stack mode (existing) remains default for the "one
thing at a time" reader.

The vertical spacing deliberately varies by recency: today uses `32px`
between cards, yesterday `20px`, earlier `12px`. This is the layout
encoding recency — denser = older.

---

## 6. New screens

### 6.1 Onboarding — first-launch flow

3 steps, full-screen sheets, skip at top right.

1. **Pick a room** — three oversized theme swatches. Not radio buttons:
   tappable 280×180 cards showing actual UI (sample article card in each
   theme on a poster). Tapping selects and animates to next step.
2. **Reader preferences** — font size 14–22 stepper, line height 1.4–1.8
   stepper, mono datelines on/off.
3. **Add a first source** — quick-tap list of 10 hand-picked starting
   sources (BBC, NYT, The Verge, Hacker News, Ars Technica, Aeon, LRB
   blog, FiveThirtyEight, Reuters AP, The Browser). Multi-select. "Add 3"
   button enables once any selected. Future Development: real OPML
   import is out of scope for this version.

State persisted as `hasCompletedOnboarding` boolean via
`SettingsService`; the splash respects this and routes accordingly.

### 6.2 Discover / Sources management

`SourcesScreen` (reached from a new 4th tab or from Settings → "Manage
sources"). Lists currently-subscribed sources with per-source unread count.
Long-press → unsave confirmation. Tap source → filter Feed to that source.
Add source FAB bottom-right opens `AddSourceSheet` with category-grouped
discover feed (10 sources/curated category), search bar, and an "Import
OPML" placeholder button (deferred — shows "Coming soon" toast).

This is the biggest UX gap in the current app: today, sources are
hardcoded. This unlocks the app.

### 6.3 Reader mode controls (ExpandedArticleCard upgrade)

Currently the expanded card has font + color baked. Replacing with:

- **Theme toggle** in a small bar at top of reader: 4 swatches (Default,
  Sepia, E-Ink, Paper). Selected theme applies to all text below.
- **Aa controls**: tap to open sheet with font size slider 14–22, line
  height slider 1.4–1.8, body font choice (DM Sans / Lora — Lora added).
- **Save / Share / Open in browser / Dismiss** — kept; quieter.

This is the place the existing design feels least custom; we restore
"reader-app" credibility here.

---

## 7. Existing screens — refinement, not replacement

### 7.1 Feed screen

- App bar: replace gradient backdrop with Folio Rule strip above existing
  category chip row. Dot-on-right of Folio is interactive (scroll to
  first unread).
- Category chips: keep as **secondary** filter (not removed) but make
  them smaller (10/4 padding) and mono-uppercase labels.
- Add **view mode toggle** (Stack vs. Continuous) as a segmented control
  in the app bar trailing area, next to the existing actions.
- Empty/loading states: redesign with editorial typography —
  "The day is quiet." for empty; "Loading the morning edition." for
  loading.

### 7.2 Settings screen

- Theme selector (currently a dropdown) → visual theme picker with three
  large swatches (~80×60) showing actual colored chips + label. Tap to
  expand a full-screen theme picker for the four reader modes.
- New section **Reading**: font size, line height, datelines toggle.
- New section **Edition**: shows current edition Nº, with a soft "(resets
  editorially on the 1st of each month)" helper.
- New entry **Manage sources** → opens SourcesScreen.
- New entry **About Curated Feeds** → story text, not version (move
  version into the story page footer).

### 7.3 Splash screen

- Keep the cube mark — it works.
- Add tag line: "A reading room."
- Move edition under logo (mono, sized small).

---

## 8. Typography in motion — how the experience feels

- **Page entrance (Feed, continuous mode):** Each section's heading eyebrow
  fades and slides in 8px from the left over 240ms, hairline extends
  outward from left over 320ms (clip-reveal).
- **Onboarding theme swatch:** Selected swatch lifts (shadow expands, scale
  1.02, 240ms); non-selected fade to 60%.
- **Folio rule:** Edition Nº ticks digit-by-digit on increment (90ms per
  digit, ease-out, 4 digits max). Cute but not overkill.
- **Empty states:** enter with `slow`, no scale — just opacity + 4px translate.
- **Category chip activate:** background swap is `fast`; underline below
  label scales from 0 to full width over `base`.

---

## 9. Content rules — written for the reader

- Voice: active, plain verbs. "Mark all read." not "Mark articles as
  read".
- Empty state copy (all three screens): a single short sentence, no
  exclamation. e.g. "Nothing saved yet." / "Tap a card to save it for
  later."
- Error copy: action + cause. "Couldn't refresh — try again when you're
  online."
- Settings row subtitles are *use*, not *feature*. "Stretch article text
  wider for shorter line reads." not "Use compact layout".
- Folio Rule copy never contains the article title; only metadata.

---

## 10. Accessibility & quality floor

- Item semantics for every interactive element (keep existing convention —
  tap = read, swipe right = save, swipe left = dismiss; long press on saved
  card = unsave).
- Focus visible on all tap targets — the curved nav already uses `InkWell`.
  Add `focusColor: primary @ 12%` to all `IconButton`s and tappable cards.
- Min touch target 48×48 (Android guideline). Current chips are 40×40
  pill — increase to 44px tall or pad inside layer.
- Color contrast: paper on ink ≥ 7.5:1; amber on paper ≥ 4.7:1 (verified
  for both states; amber never carries body). Reader modes pass AA in
  all four.
- Reduced motion: respected (existing grain-overlay guard extended to
  edition animation, sheet spring, swatch lift).
- Font scaling: widgets use `MediaQuery.textScalerOf(context)` capped at
  1.4× to prevent layout breakage; titles stay readable up to 2.0×.
- No emojis as affordance icons (kept from audit checklist).

---

## 11. Out of scope (deferred)

These are real features that would help, but explicitly not part of this
redesign pass:

- Real OPML import
- Server-side sync of read state
- Folder/tag organization beyond Categories
- Today widget / quick tile
- AI summary / TL;DR
- Highlight + annotation
- Newsletter (email/RSS hybrid) sources

If any of these belong, that's a separate spec. This one ships a *better
reading room*, not a re-platform.
