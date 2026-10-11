# Handoff — metrics-based layout & PDF parity

Date: 2026-09-28
Repo: `red-report-generator`
Branch: `main` (base `df44d37`). The work below plus the follow-up section under
"PDF line-box & baseline parity" is now committed.

## What this session did

1. **DRAW-BG** (optional raw page background) — parser, View and PDF support.
2. **End whitespace preserved** — trailing spaces in a value are kept so a
   background color covers them.
3. **Metrics-based layout refactor** — line boxes and column widths now come from
   one measured source per renderer instead of `size × factor` guesses.
4. **Box tuning** — per-family insets so backgrounds hug the text, 1px row gap.
5. **PDF parity** — mirrored metrics/insets/column advance; fixed `transparent`.

## Layout model (current)

Single interface, one implementation per renderer:

- `text metrics`: `func [text styles] -> [width height ascent]` (px/pt).
  - View: `report-view/view-metrics` via `size-text/with` (`"hg"` = height,
    `"h"` = ascent).
  - PDF: `report-pdf/pdf-metrics` via Base-14 AFM; `height = font-size ×
    font-scale × line-height-factor`, `ascent = height` (so header/first-line
    spacing matches View).
  - Fallback: `report-styles/default-metrics`.
- Shared helpers in `report-styles.red`, each taking the **metrics function
  explicitly**: `line-ink`, `line-step`, `line-advance`, `footer-height`,
  `row-height`, `measure-column-pixels`.
- `line-gap-px` (default **1**) is the only spacing knob. Baseline step is
  `descent(prev) + line-gap-px + ascent(next)`; a line's height is the max of its
  values' measured heights; boxes just touch with the gap.

### Red gotchas discovered (important)

- Passing a function value as a normal argument **calls it**. Always pass with
  `:f` (get-word) and inside functions copy it first:
  `f: get/any 'metrics` then call `do reduce [f text styles]` or `line-ink x :f`.
- `(expr)/index` is unreliable in Red 0.6.6 — assign to a temp first.
- `array/initial` + `poke` (not `ys/:n:`) for dynamic blocks.
- `case [f x = 'mono [..]]` mis-parses; compare to a local temp.
- Multiline strings in docstrings are syntax errors — keep them single-line.

### Per-family box insets (background/frame only; layout uses raw metrics)

Applied in both renderers so boxes hug the glyphs and share one geometry:

| family | View (btop/bbot) | PDF (btop/bbot) |
|--------|------------------|-----------------|
| mono   | −3 / −2          | −3 / −3         |
| sans   | −2 / −1          | −2 / −2         |
| serif  | 0 / −1           | −2 / −2         |

View boxes are the measured box plus insets (`bt = dy − ascent + btop`,
`bb = dy − ascent + fh + bbot`). PDF box height must be `advance − 1` to leave
the 1px gap (rows advance by `line-advance`).

### Column auto-width

`measure-column-pixels` (shared in `report-styles.red`, View copy in
`report-view.red`) now measures the **formatted text** with the merged per-value
styles via the metrics function — no more `length × font-size × 0.583`.

### Block-after-text step

Before stacking a COLUMN/TABLE/IMAGE, both renderers step the cursor past the
preceding text line: `page-y -= line-ink(prev-line)/2 + line-gap-px`, then clear
`prev-line`. This fixed the first body line being covered by the table.

### Transparency

`report-styles/opaque-tuple?` — Red 4-tuples are **RGBA with alpha first**, so
`0.0.0.255` (`transparent`) has alpha 0. Both renderers drop alpha-0
backgrounds/frames (incl. table cells), so `transparent` paints nothing.

## Verification

- `red tests/check.red` → 19/19 PASS, exit 0.
- `red tests/check.red --pdf` → 19/19 PASS, exit 0.
- `color-picker.red` rendered in View (`/tmp/kilo/cp_render.red`) and PDF
  (`/tmp/kilo/cp_pdf.red`); rasterized with `pdftoppm -png -r 72` and compared
  1:1 at 800×900. Rows now 26px at 27px pitch (PDF) vs 18px at 19px (View) —
  both with a 1px gap; transparent row unpainted in both.

## Files in this change set

```
 M README.md
 M docs/reboot-plan.md
 M docs/report-syntax-spec.md
 M libs/report-parser.red
 M libs/report-pdf.red
 M libs/report-styles.red
 M libs/report-view.red
 M sampler2.red
?? color-picker.red
?? docs/handoff-metrics-pdf-parity.md
?? samples/025-draw-bg.red
```

## PDF line-box & baseline parity (follow-up)

The View measures its OS font's line box via `size-text`; the PDF used
`(font-size × font-scale) × line-height-factor`, which double-counted the
dpi scale (27px rows vs the View's 19px) and drew text on a baseline instead
of from the line-box top (glyphs ~7px low).

- `report-pdf/pdf-metrics` now returns the line box from the **nominal** size
  and per-family `line-scale-serif/sans/mono` (serif 12→19, mono/sans 12→17;
  h1/h2/h3 24/18/14→36/28/22), while AFM advance widths keep the glyph scale.
- Text baseline = `y + h − ascender − heading-lead` (`font-ascent-for`), so
  glyphs land where the View draws them.
- Background/frame insets now mirror the View exactly (mono −3/−2, sans
  −2/−1, serif 0/−1).
- Column text rows advance by `line-height` like the View (not `line-advance`),
  and `usable-top`'s no-first-line fallback uses `default-metrics`.

Verified 1:1 (72 dpi raster vs View PNG) on color-picker, table (2pp), hello
and image (3pp); `tests/check.red` 19/19 with and without `--pdf`.

## Known remaining PDF/View differences

1. ~~**PDF header sits a few px higher**~~ — resolved by the follow-up: the
   header/baseline now lands on the View's position (measured identical).
2. **PDF glyphs slightly larger/wider** — Helvetica/Times/Courier Base-14 vs the
   OS faces; visible inside identical boxes. Expected; tune only if it matters.
3. ~~**PDF first table row starts lower**~~ — resolved by the follow-up.
4. `report-styles/measure-column-pixels` still has a View copy; PDF uses the
   shared one. Consider unifying into one call.
5. `report-styles/line-advance` remains for image-caption spacing; `line-gap-px`
   no longer interacts with it.
6. Lower h2/h3 heading boxes can drift 1–2px vs the View (rounded line heights
   accumulate); body text and boxes otherwise align.

## Update: true ascent/descent (mixed-family baselines)

The earlier model set `ascent = height` (descent 0) and compensated with per-family
box insets, so values in different families each sat their own descent above the line
baseline (mono ~2-3px high vs serif in the View; the PDF misaligned the other way).

`report-styles/box-ascent-frac` now splits the measured line box into a true
`ascent`/`descent` per family (serif 0.79, sans 0.715, mono 0.60 of the box height).
Both `view-metrics` and `pdf-metrics` return that ascent; text is placed on the
baseline, and boxes span the line box `[baseline - descent, baseline + ascent]` — the
per-family `btop`/`bbot` insets and the PDF `font-ascent-for` fractions are gone.
Line stepping (`descent(prev) + line-gap-px + ascent(next)`) is unchanged for a
uniform font, so page counts are unaffected; `tests/check.red` and `--pdf` stay at
26/27 (one pre-existing `005-Complex-Demo-mod.red` scratch failure). Verified 1:1
(72 dpi) on hello/sections/styles/table and a mono+serif row: families share one
baseline in both renderers, View/PDF within ~1px.

## Handy probe/measure snippets

- View render to PNG: build a `report-view`, `generate parse-report report`,
  `save/as %out.png (to-image (v/render-page page 100)) 'png`, run under
  `red-view` (headless `red` has no `draw`; `draw` there is a silent no-op).
- PDF: `report-pdf/generate pg %out.pdf`, then
  `pdftoppm -png -r 72 out.pdf pref` for 1:1 (page pts == px at 72 dpi).
- Row/band measurement: scan a column x for color changes; band height vs pitch
  gives the gap.
