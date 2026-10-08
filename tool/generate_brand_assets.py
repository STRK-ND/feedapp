#!/usr/bin/env python3
"""Derive every Curated Feeds raster asset from the single `logo.png` source.

Run from anywhere:  python3 tool/generate_brand_assets.py

Idempotent: running twice produces byte-identical output. The generated
files are committed, so nothing in CI invokes this script -- `flutter build`
must never depend on Python being installed.

    logo.png  (repo root, pristine master, never written to)
      |
      +--> assets/brand/logo.png          512  full tile   -> Image.asset in-app
      +--> assets/brand/mark.png          432  mark only   -> adaptive foreground
      +--> assets/brand/mark_mono.png     432  white glyph -> adaptive monochrome
      +--> android/.../mipmap-*/ic_launcher_round.png   48..192  (API 25 only)
      +--> android/.../drawable-*/launch_image.png     96..384  legacy splash
      +--> marketing/icon-512.png                    512  opaque, de-corned
      +--> marketing/feature-graphic-1024x500.png          Play feature graphic

`dart run flutter_launcher_icons` consumes the first three and produces the
adaptive layers, the legacy `ic_launcher.png` rasters and the
`mipmap-anydpi-v26/ic_launcher.xml`. It cannot do anything else, so this
script is load-bearing for the splash, the round rasters and the Play
graphics.

Why `r - b` and not brightness or saturation
--------------------------------------------
Measured over all 164,113 opaque pixels of the current source:

    warm (the mark)   r-b >= 12    101,372 px    min =  12
    navy (the ground) r-b <=  -1    38,347 px    max =  -1
    antialiased band  r-b in [0, 11] 24,394 px
    -> ZERO overlap

Saturation and brightness both fail outright here. Relative luminance
spans 0.789 for the navy rim highlight down to 0.0008 for the swirl's
shadow, and 66.5% of pixels are ground with median saturation up to 78.6
-- a brightness threshold yields a solid disc, a saturation threshold
leaks the entire plate.

Red-minus-blue separates cleanly because the two families have opposite
dominant channels: the ground is blue-dominant (38,330 of 38,347 have b
as the max channel), the mark is red-dominant (101,372 of 101,372).

The residual navy left in the glow by the soft ramp is invisible, because
every consumer of `mark.png` puts it on `AppColors.ground` (#0E0814).

TUNABILITY: the ramp bounds below are tuned to *this* artwork. A future
logo revision must be re-inspected, not assumed.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "logo.png"

# --- warm key ---------------------------------------------------------------
# Ramp bounds on (r - b). Measured: ground never exceeds 11, mark never
# drops below 12. Starting the ramp at 8 puts the antialiased boundary at
# near-zero alpha; completing it by 42 makes solid ink solid while letting
# the swirl's dark shadow survive as a soft warm bloom against the navy.
KEY_LO = 8
KEY_HI = 42

ALPHA_FLOOR = 8  # ignore the near-transparent fringe around the squircle

# --- adaptive icon geometry -------------------------------------------------
# Android adaptive icons are a 108dp canvas; the guaranteed-visible safe zone
# is a 66dp circle. flutter_launcher_icons resizes the foreground PNG to
# 108dp-equivalent pixels with no padding of its own, so the padding has to
# be baked in here and `adaptive_icon_foreground_inset` must be 0 (its
# default of 16 would emit <inset android:inset="16%"/> and shrink our
# correctly-sized 66dp mark to 45dp).
#
# 4 px per dp, so 432 px == 108 dp and 432 * 66/108 == 264 px == 66 dp.
FG_CANVAS_PX = 432
FG_SAFE_DP = 66

# --- glyph (used for the monochrome layer) ----------------------------------
# The swirl cannot be a themed icon: it is a tonal gradient, so its alpha
# matte is ~64% ink coverage and renders as a solid disc at 48dp. Measured
# blob count of the full silhouette climbs 4 -> 41 across 24..192px, i.e. it
# fragments into debris. The RSS glyph holds exactly 3 blobs (dot + two
# arcs) at 24/32/48/96px.
#
# The glyph is fitted through the *same* transform as the mark rather than
# centred independently, so the themed icon is perfectly co-registered with
# the colour one instead of appearing 2.6x larger.
GLYPH_SAT_MAX = 0.45
GLYPH_LUM_MIN = 120.0
GLYPH_GATE_FRACTION = 0.46  # central disc, as a fraction of min(w, h)
GLYPH_COMPONENTS = 3

# --- density buckets --------------------------------------------------------
# (launcher legacy px, legacy splash px)
DENSITIES = {
    "mdpi": (48, 96),
    "hdpi": (72, 144),
    "xhdpi": (96, 192),
    "xxhdpi": (144, 288),
    "xxxhdpi": (192, 384),
}

# Mirrors AppColors.ground in lib/utils/design_tokens.dart. Used as the
# de-corner fill for the Play icon and the feature-graphic ground.
GROUND = (0x0E, 0x08, 0x14)  # #0E0814

# Mirrors AppColors.curation. Used for the feature graphic's rule.
AMBER = (0xC4, 0x94, 0x4E)  # #C4944E

IN_APP_PX = 512
PLAY_PX = 512


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _blank(size: tuple[int, int]) -> Image.Image:
    return Image.new("RGBA", size, (0, 0, 0, 0))


def _saturation(rgb: tuple[int, int, int]) -> float:
    hi, lo = max(rgb), min(rgb)
    return 0.0 if hi == 0 else (hi - lo) / hi


def _luminance(rgb: tuple[int, int, int]) -> float:
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def _square_crop(image: Image.Image) -> Image.Image:
    """Centre-crop to the squircle's alpha bbox, then square-pad.

    The source plate measures 417x414 -- three pixels wider than tall, and
    sitting eight pixels above the canvas centre. Rendering that into a
    square box would squash it, so pad (never crop) to square.
    """
    box = image.getchannel("A").getbbox()
    plate = image.crop(box)
    side = max(plate.size)
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.alpha_composite(plate, ((side - plate.width) // 2, (side - plate.height) // 2))
    return out


def _segment_mark(image: Image.Image) -> Image.Image:
    """Key the navy ground out, keeping the swirl and the RSS glyph."""
    width, height = image.size
    source = image.load()
    pixels: list[tuple[int, int, int, int]] = []
    for y in range(height):
        for x in range(width):
            r, g, b, a = source[x, y]
            if a < ALPHA_FLOOR:
                pixels.append((0, 0, 0, 0))
                continue
            warm = _clamp(((r - b) - KEY_LO) / (KEY_HI - KEY_LO), 0.0, 1.0)
            pixels.append((r, g, b, int(a * warm)))
    out = _blank((width, height))
    out.putdata(pixels)
    return out


def _largest_components(points: set[tuple[int, int]], count: int) -> list[list[tuple[int, int]]]:
    """`count` largest 4-connected components of `points`, biggest first.

    Exhaustive: every component is found before sorting, so the result is
    genuinely the largest ones rather than the largest of an arbitrary
    prefix. The gated cream set is ~11k pixels / <100 components; the full
    scan is sub-0.1 s.
    """
    remaining = set(points)
    components: list[list[tuple[int, int]]] = []
    while remaining:
        seed = remaining.pop()
        queue = deque([seed])
        blob = [seed]
        while queue:
            x, y = queue.popleft()
            for neighbour in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if neighbour in remaining:
                    remaining.discard(neighbour)
                    queue.append(neighbour)
                    blob.append(neighbour)
        components.append(blob)
    # Tiebreak on the smallest coordinate so the order is deterministic
    # even with PYTHONHASHSEED randomisation: set-pop discovery order is
    # arbitrary, and a tie exactly at the keep/drop boundary would otherwise
    # select a different set on different runs.
    components.sort(key=lambda blob: (len(blob), min(blob)), reverse=True)
    return components[:count]


def _fail(message: str) -> SystemExit:
    """One failure style for every guard in this script.

    This is a build-time generator, never imported: a loud message and a
    non-zero exit beats a traceback for one class of problem and silence
    for another.
    """
    return SystemExit(f"generate_brand_assets: {message}")


def _segment_glyph(image: Image.Image) -> Image.Image:
    """The cream RSS glyph as a white silhouette, same canvas as the source.

    Selects the largest connected components of the "cream" predicate inside
    a central radial gate around the mark's ink centroid.

    The gate is nearly inert on the current source (it drops a handful of
    pixels) and is kept as insurance: a future swirl highlight bright
    enough to pass the cream test would otherwise merge the glyph with the
    swirl into one component.

    The two arcs and the dot are separate components because the glyph is
    shaded darker toward its lower edge, so the arcs never touch under a
    hard threshold. Selecting the largest N -- rather than flood-growing one
    seed -- is what makes this robust. Measured component areas for the
    current source: 5979 / 3754 / 1083 / 85 -- a ~13x gap at the selection
    boundary, so the choice of 3 is unambiguous.
    """
    width, height = image.size
    source = image.load()

    warm_count = 0
    centre_x = 0.0
    centre_y = 0.0
    cream: list[tuple[int, int]] = []
    for y in range(height):
        for x in range(width):
            r, g, b, a = source[x, y]
            if a < ALPHA_FLOOR or (r - b) < KEY_HI:
                continue
            warm_count += 1
            centre_x += x
            centre_y += y
            rgb = (r, g, b)
            if _saturation(rgb) < GLYPH_SAT_MAX and _luminance(rgb) > GLYPH_LUM_MIN:
                cream.append((x, y))

    if warm_count == 0:
        raise _fail("no mark pixels found; check KEY_HI")

    centre_x /= warm_count
    centre_y /= warm_count
    gate = (GLYPH_GATE_FRACTION * min(width, height)) ** 2
    gated = {
        (x, y)
        for x, y in cream
        if (x - centre_x) ** 2 + (y - centre_y) ** 2 <= gate
    }

    if len(blobs := _largest_components(gated, GLYPH_COMPONENTS + 1)) < GLYPH_COMPONENTS:
        raise _fail(
            f"glyph extraction found {len(blobs)} components, expected at least "
            f"{GLYPH_COMPONENTS}"
        )

    # The invariant is the size GAP at the selection boundary, not the ratio
    # to the largest blob: the dot is legitimately much smaller than the two
    # arcs. A missing fourth component is the ideal case (no noise at all),
    # not an error — the gap is then trivially satisfied.
    kept = blobs[:GLYPH_COMPONENTS]
    smallest_kept = len(kept[-1])
    biggest_dropped = (
        len(blobs[GLYPH_COMPONENTS]) if len(blobs) > GLYPH_COMPONENTS else 0
    )
    if biggest_dropped * 4 > smallest_kept:
        raise _fail(
            f"glyph component {GLYPH_COMPONENTS + 1} ({biggest_dropped} px) is not "
            f"clearly smaller than component {GLYPH_COMPONENTS} ({smallest_kept} px); "
            f"the source logo probably changed shape"
        )

    keep = {(x, y) for blob in kept for x, y in blob}
    pixels = [
        (255, 255, 255, 255) if (x, y) in keep else (255, 255, 255, 0)
        for y in range(height)
        for x in range(width)
    ]
    out = _blank((width, height))
    out.putdata(pixels)
    return out


def _fit_pair(mark: Image.Image, glyph: Image.Image) -> tuple[Image.Image, Image.Image]:
    """Fit both layers through ONE transform so they stay co-registered.

    The mark's ink is scaled so its widest side equals 66/108 of the canvas,
    then centred. Applying the identical crop + scale + offset to the glyph
    is what keeps the themed icon the same size and position as the colour
    one. `max()` rather than `min()`: the swirl is a ring, so scaling by the
    smaller dimension would push its horizontal tips outside the safe zone.
    """
    box = mark.getchannel("A").getbbox()
    if box is None:
        raise _fail("segment produced no ink; check KEY_LO / KEY_HI")

    target = FG_CANVAS_PX * FG_SAFE_DP // 108
    scale = target / max(box[2] - box[0], box[3] - box[1])

    def place(layer: Image.Image) -> Image.Image:
        cropped = layer.crop(box)
        resized = cropped.resize(
            (
                max(1, round(cropped.width * scale)),
                max(1, round(cropped.height * scale)),
            ),
            Image.LANCZOS,
        )
        canvas = _blank((FG_CANVAS_PX, FG_CANVAS_PX))
        canvas.alpha_composite(
            resized,
            ((FG_CANVAS_PX - resized.width) // 2, (FG_CANVAS_PX - resized.height) // 2),
        )
        return canvas

    return place(mark), place(glyph)


def _circle_mask(image: Image.Image, size: int) -> Image.Image:
    """Scale to `size` and clip to a circle.

    Only consumed by `ic_launcher_round.png`, which Android uses on API 25
    and below -- adaptive icons are API 26+. Scaling to 0.94 first because
    on pre-26 the OS does not inset the icon, so the full 48dp is drawn.
    """
    side = round(size * 0.94)
    art = image.resize((side, side), Image.LANCZOS).convert("RGBA")
    canvas = _blank((size, size))
    canvas.alpha_composite(art, ((size - side) // 2, (size - side) // 2))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    canvas.putalpha(
        Image.composite(
            canvas.getchannel("A"), Image.new("L", (size, size), 0), mask
        )
    )
    return canvas


def _save(image: Image.Image, relative: str) -> None:
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    print(f"  {relative:<62} {image.size[0]:>4} x {image.size[1]:<4}")


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"missing source: {SOURCE}")
    print(f"Generating brand assets from {SOURCE.relative_to(ROOT)}")

    source = Image.open(SOURCE).convert("RGBA")
    tile = _square_crop(source)

    _save(tile.resize((IN_APP_PX, IN_APP_PX), Image.LANCZOS), "assets/brand/logo.png")

    mark = _segment_mark(source)
    glyph = _segment_glyph(source)
    fitted_mark, fitted_glyph = _fit_pair(mark, glyph)
    _save(fitted_mark, "assets/brand/mark.png")
    _save(fitted_glyph, "assets/brand/mark_mono.png")

    for suffix, (launcher_px, splash_px) in DENSITIES.items():
        _save(
            _circle_mask(tile, launcher_px),
            f"android/app/src/main/res/mipmap-{suffix}/ic_launcher_round.png",
        )
        _save(
            tile.resize((splash_px, splash_px), Image.LANCZOS),
            f"android/app/src/main/res/drawable-{suffix}/launch_image.png",
        )

    # Play Console: 512x512, fully opaque, full square. Play applies its own
    # 30% corner radius, and the logo is already a squircle (best-fit
    # superellipse n=4.75), so shipping it as-is yields a rounded square
    # inside a rounded square with 33% of the displayed area transparent.
    # Filling the field with the brand ground and letting Play clip the
    # corners gives one clean silhouette.
    play = Image.new("RGBA", (PLAY_PX, PLAY_PX), GROUND + (255,))
    scaled = tile.resize((PLAY_PX, PLAY_PX), Image.LANCZOS)
    play.alpha_composite(scaled)
    _save(play.convert("RGB"), "marketing/icon-512.png")

    # Feature graphic: no text, by design. `google_fonts` fetches Playfair
    # at runtime and this script has no font access, so any typography here
    # would need a bundled font file or a second source of truth. Play
    # overlays the app title on several surfaces anyway. The amber rule
    # echoes the in-app folio rule.
    feature = Image.new("RGB", (1024, 500), GROUND)
    tile_size = 400
    feature_tile = tile.resize((tile_size, tile_size), Image.LANCZOS)
    feature.paste(feature_tile, (512 - tile_size // 2, 250 - tile_size // 2), feature_tile)
    ImageDraw.Draw(feature).rectangle(
        (512 - 110, 250 + tile_size // 2 + 20, 512 + 110, 250 + tile_size // 2 + 21),
        fill=AMBER,
    )
    _save(feature, "marketing/feature-graphic-1024x500.png")

    print("\nNext: dart run flutter_launcher_icons")


if __name__ == "__main__":
    main()