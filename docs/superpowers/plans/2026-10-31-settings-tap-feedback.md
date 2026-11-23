# Interactive Settings Touch Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status: implemented and verified in-session (2026-10-31). Tasks 1–2 are complete and their steps are checked; Tasks 3–4 are the remaining hardening and documentation work.**

**Goal:** Restore visible touch feedback (ink splash) on every interactive row in the Settings screen.

**Architecture:** `_buildSettingsCard` groups tiles inside a `Container` whose translucent `BoxDecoration` fill is a `DecoratedBox` sitting between the tiles and the screen-level `Material`. `ListTile` paints its background and ink splashes on its nearest `Material` ancestor, so the card wash covered the tile's paint. The fix inserts one `MaterialType.transparency` child inside the card, carrying the card's 16px radius, so it becomes that nearest ancestor and the ink paints inside the card.

**Tech Stack:** Flutter 3.10.8 / Dart, `flutter_test` (widget tests with a faked service graph through `get_it`), `provider`.

**Spec / authority:** No project spec covers this. The authority is the Flutter framework's own `ListTile` ink contract, in the pinned SDK at `/home/adam/snap/flutter/common/flutter/packages/flutter/lib/src/material/list_tile.dart` — `_debugCheckBackgroundIsHidden` (line 1147), `_findIntermediateWidget` (line 1181), and the trigger condition at line 833 (`onTap != null || onLongPress != null || hasOpaqueBackground`). Read those three before implementing. The design intent this restores is in `docs/superpowers/specs/2026-07-11-curated-feeds-redesign-design.md` (settings rows as tappable editorial surfaces).

## Global Constraints

- No new dependencies — the fix uses only framework `Material`.
- No test ids, agent-actions or debug hooks added to `lib/` (`docs/testing/mobile-e2e.md`: "No app changes for tests").
- Widget tests must be deterministic and hermetic: fakes for `ConnectivityPlatform`, `FirebasePlatform`, `FirebaseAnalyticsPlatform`, `GoogleFonts.config.allowRuntimeFetching = false`, in-memory `StorageService`, `SharedPreferences.setMockInitialValues({})`, `getIt.reset()` per test.
- Fixed pumps, not `pumpAndSettle` — `google_fonts` keeps timers alive.
- The Settings body is a lazy `ListView`; a row only exists while its section is on screen, so any coverage claim must traverse the whole scroll journey (down and back up), not inspect one final position.

## Review Focus

Failure modes the framework contract implies that no task's tests exercise, most likely to bite first:

1. **A row with no `onTap` must stay non-interactive** — the About "App Version" row and every `_buildInfoTile` (Cached articles, Saved articles, font size, line height, body font) share this card. Wrapping them in an ink-hosting `Material` must not make them look or act tappable. *Test: the fix's own test file already skips `tile.onTap == null`; Task 1 must keep that filter and assert the About row's tap still does nothing.*
2. **Narrow viewports** — Settings renders at 320/360/412/480/600dp and an extra wrapper must not introduce `RenderFlex overflowed`. *Test: assert zero overflow at each width after the full scroll.*
3. **Both themes** — the card fill is `surfaceContainerHighest` at alpha 0.30, and each theme defines that role with a different base colour, so the wash behaves differently over each. *Test: run the invariant under `Brightness.light` and `Brightness.dark`.*
4. **An opaque `ListTile.tileColor` in the same card** — a future row setting `tileColor:` to a nonzero-alpha colour reintroduces exactly this bug per-tile, because `hasOpaqueBackground` independently trips the framework check. *Test: assert no interactive `ListTile` inside a `_buildSettingsCard` resolves a nonzero-alpha `tileColor`.*
5. **A row added later** — the fix lives in the shared `_buildSettingsCard` builder, so new interactive rows are covered automatically, but only if the test enumerates from the running screen instead of a hardcoded title list. *Test: derive the offending-row list from `find.byType(ListTile).evaluate()`.*

---

### Task 1: Regression test for the invisible-splash invariant

**Files:**
- Create: `test/unit/screens/settings_tap_feedback_test.dart`
- Test: same file

**Interfaces:**
- Consumes: nothing — this is the first task.
- Produces: the invariant helper `_opaqueBackgroundBetweenTileAndInk(Element tile) → String?`, which Task 2's fix must make return `null` for every interactive row. Also produces the test harness `pumpSettings(WidgetTester)`, reused by Task 3.

- [x] **Step 1: Write the failing test**

Create `test/unit/screens/settings_tap_feedback_test.dart`. One test, `'every interactive Settings row shows its tap feedback'`. Pump `SettingsScreen` inside `ChangeNotifierProvider<SettingsNotifier>` at `Size(412, 900)`, then traverse the lazy list (40 drags of `Offset(0, -500)` down, 40 of `Offset(0, 500)` back up, 30 ms pumps) collecting distinct offending rows, where a row offends when it has `tile.onTap != null` and `_opaqueBackgroundBetweenTileAndInk` returns non-null.

The helper replicates the framework's own walk exactly:

```dart
String? _opaqueBackgroundBetweenTileAndInk(Element tile) {
  String? culprit;
  tile.visitAncestorElements((ancestor) {
    if (ancestor.widget is Material) return false;
    final color = switch (ancestor.widget) {
      ColoredBox(:final Color color) => color,
      DecoratedBox(decoration: BoxDecoration(:final Color? color)) => color,
      DecoratedBox(decoration: ShapeDecoration(:final Color? color)) => color,
      _ => null,
    };
    if (color != null && color.a > 0) {
      culprit = ancestor.widget.runtimeType.toString();
      return false;
    }
    return true;
  });
  return culprit;
}
```

Assert `expect(offenders, isEmpty, reason: '…the tap gives the user no visible feedback')`.

- [x] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/unit/screens/settings_tap_feedback_test.dart --reporter expanded`
Expected: FAIL. The measured offenders are all seven interactive rows:
`Alert categories`, `Manage sources`, `Reader preferences`, `Clear Cache`,
`Open Source Licenses`, `Support the app`, `Report bug / Feedback` — each
`via DecoratedBox`. (A naive version that inspects only the final scroll
position reports just one row; the down-and-up traversal is required to catch
all seven. That is why Step 1 says traverse, not settle.)

- [x] **Step 3: Commit the failing test**

```bash
git add test/unit/screens/settings_tap_feedback_test.dart
git commit -m "test(settings): fail when an interactive row hides its ink splash"
```

---

### Task 2: Restore the ink host inside the settings card

**Files:**
- Modify: `lib/screens/settings_screen.dart:654-679` (`_buildSettingsCard`)

**Interfaces:**
- Consumes: the harness in Task 1.
- Produces: `_buildSettingsCard` returns a card whose nearest `Material` ancestor for its tiles is a `MaterialType.transparency` widget inside the card, so `_opaqueBackgroundBetweenTileAndInk` returns `null` for every interactive row.

- [x] **Step 1: Wrap the card's column in a transparency `Material`**

In `_buildSettingsCard`, replace `child: Column(...)` with a `Material` that carries that same `Column`. Exact widget:

```dart
child: Material(
  type: MaterialType.transparency,
  borderRadius: BorderRadius.circular(16),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: _divideTiles(children),
  ),
),
```

Approach, and why this shape and not the alternatives: `MaterialType.transparency` is documented in the pinned SDK as "A transparent piece of material that draws ink splashes and highlights… can be placed on top of opaque widgets to show ink effects on top of them" (`material.dart:52`). `borderRadius` carries the card's own 16px radius so the splash is inset to the card's rounded bounds rather than its rectangle's corners. `clipBehavior` defaults to `Clip.none`, so no child is clipped and no layout changes. The two rejected alternatives — dropping the card's background colour (changes the documented visual design) or wrapping each `ListTile` in its own `Material` (seven edit sites, drifts from the shared builder, and leaves the next added row broken) — both fail the reviewer's "why here and not there" question.

Leave a comment above the `Material` naming the failure it fixes and citing the framework diagnostic, in the file's existing prose-comment style.

- [x] **Step 2: Run the test and confirm it passes**

Run: `flutter test test/unit/screens/settings_tap_feedback_test.dart --reporter expanded`
Expected: PASS (`All tests passed!`).

- [x] **Step 3: Prove the test gates the fix (not vacuous)**

Revert only the source, re-run the test, then restore. If the test passes while
the fix is stashed, it is vacuous and must be rewritten before continuing.

Run: `git stash push -- lib/screens/settings_screen.dart && flutter test test/unit/screens/settings_tap_feedback_test.dart --reporter expanded; git stash pop`
Expected: FAIL with all seven rows while stashed, then PASS again after the pop.

- [x] **Step 4: Run the whole suite and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` at **275 tests** (274 pre-existing + this one new) and `No issues found!`.

- [x] **Step 5: Commit the fix**

```bash
git add lib/screens/settings_screen.dart
git commit -m "fix(settings): give interactive rows their tap feedback back"
```

---

### Task 3: Guard the four reintroduction paths

**Files:**
- Modify: `test/unit/screens/settings_tap_feedback_test.dart` (extend the existing test)
- Test: same file

**Interfaces:**
- Consumes: `pumpSettings`, `_opaqueBackgroundBetweenTileAndInk`, and the scroll traversal from Tasks 1–2.
- Produces: the same test now failing if any of the four Review Focus conditions regress.

- [ ] **Step 1: Add the narrow-viewport overflow guard**

Extract the scroll traversal from Task 1's test into a parameterised helper over width `{320, 360, 412, 480, 600}`, and at each width capture `FlutterError.onError` and assert zero `A RenderFlex overflowed` after the full traversal. Keep the Task 1 invariant assertion at 412dp so the original defect stays pinned at the reference width.

- [ ] **Step 2: Add the both-themes guard**

Pump under `MaterialApp(theme: ThemeData(brightness: Brightness.light), themeMode: ThemeMode.light)` and again with `Brightness.dark`, running the Task 1 invariant in both. Do not swap in a bare `ThemeData` for the app's real themes — `lib/providers/theme_provider.dart` defines `surfaceContainerHighest` explicitly for both, and the guard must exercise those values, so use the real `ThemeProvider.lightTheme` / `darkTheme`.

- [ ] **Step 3: Add the non-interactive-rows guard**

Assert that the About "App Version" row (`ListTile` with no `onTap`) still renders and that tapping its centre changes nothing observable — no navigation, no dialog. This pins Review Focus 1: the ink host must not create interactivity.

- [ ] **Step 4: Add the opaque-tileColor guard**

Assert that no interactive `ListTile` inside a `_buildSettingsCard` resolves a nonzero-alpha tile colour, via `theme.listTileTheme.tileColor`, `ListTileTheme.of(context).tileColor`, or the tile's own `tileColor`. This pins Review Focus 4.

- [ ] **Step 5: Run and confirm green**

Run: `flutter test test/unit/screens/settings_tap_feedback_test.dart --reporter expanded`
Expected: `All tests passed!` across every width/theme permutation.

- [ ] **Step 6: Commit**

```bash
git add test/unit/screens/settings_tap_feedback_test.dart
git commit -m "test(settings): pin tap feedback across widths, themes and non-interactive rows"
```

---

### Task 4: Documentation and the device-visibility gap

**Files:**
- Modify: `docs/testing/mobile-e2e.md:207` (the "Verified runs" row)
- Modify: `CHANGELOG.md:8-11` (the Unreleased → Fixed entry, already drafted)

**Interfaces:**
- Consumes: nothing.

- [ ] **Step 1: Add the changelog entry**

Add under `## [Unreleased]` a `### Fixed` entry stating that every interactive Settings row gave no tap feedback, naming all seven rows, describing the cause (the card's translucent fill covering the tile's `InkDecoration` and splash), the measured before/after ink-host render depth (43 → 3), the fix (a `MaterialType.transparency` child with the card's 16px radius and no clipping), and the regression test by path. Follow the existing entries' style: bolded lead clause, then the evidence, then `Regression: <path>`.

- [ ] **Step 2: Refresh the stale test count**

`docs/testing/mobile-e2e.md:207` records "`flutter test` (270 tests, all passed)". Update to the current count and add the date and the verification commands that were actually run (`flutter test`, `flutter analyze`, `cd workers && npm test`).

- [ ] **Step 3: Record the device-visibility gap honestly**

The defect is proven at the widget/render-object level, but not visually on hardware: this checkout has no Android SDK (`adb not found in PATH`), so the 27 device e2e tests cannot run and no screenshot of the splash exists. State this in the same "Verified runs" row rather than implying device confirmation. Do not claim visual verification that did not happen.

- [ ] **Step 4: Confirm green and commit**

Run: `flutter test && flutter analyze`
Expected: unchanged — `All tests passed!` at 275 and `No issues found!`.

```bash
git add CHANGELOG.md docs/testing/mobile-e2e.md
git commit -m "docs: record the settings tap-feedback fix and the device-visibility gap"
```

---

## Self-Review

**1. Coverage.** The defect (invisible ink on interactive Settings rows) is implemented by Task 2 and pinned by Task 1's invariant; the four Review Focus conditions are pinned by Task 3; the delivery requirements (changelog, doc accuracy, honest limit) are Task 4. Nothing in the plan invents scope beyond the defect and its guards.

**2. Step scan.** Task 2 Step 1 gives the exact widget, the exact file and line range, and the rejected alternatives — one reasonable implementation. Task 1 Step 1 gives the helper verbatim because its shape is the point and the implementer must not improvise it. Where a step carries a "why" it is because the signature alone leaves a real choice open.

**3. Type consistency.** `_opaqueBackgroundBetweenTileAndInk(Element) → String?`, `pumpSettings(WidgetTester) → Future<void>` are defined in Task 1 and referenced by Tasks 2–3 with the same names and signatures.

**4. Review Focus.** All five conditions have a pinning test in Task 3, except condition 1 which Task 1's `tile.onTap == null` filter already pins implicitly and Task 3 Step 3 makes explicit.

**5. Proportion.** The plan carries two code blocks (the helper, the fix widget) and one measurement table. It is shorter than the change it describes.
