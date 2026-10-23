# Red Report Generator — agent notes

Red script library that turns a block-based report description into a paginated
View document and/or a PDF. No build step; run the scripts with Red.

## Layout

| Path | Purpose |
|---|---|
| `libs/report-parser.red` | parse + validate the report block into a page object |
| `libs/report-styles.red` | shared style/word/metrics/INK helpers (base of both renderers) |
| `libs/report-view.red` | Red/View renderer + viewer (hotspots, zoom, PDF button) |
| `libs/report-pdf.red` | PDF renderer (Base-14 fonts, JPEG or lossless Flate images + `/SMask` alpha) |
| `libs/pdf-kit.red` | minimal PDF writer |
| `samples/` | runnable demos and the `tests/check.red` fixtures |
| `assets/` | images and the generated `what-functions.txt` snapshot |
| `docs/report-syntax-spec.md` | authoritative syntax reference |
| `docs/cheatsheet.md` | condensed “what may I write here” |
| `tests/check.red` | headless parse/validate/render harness |

## Build / test

```bash
red tests/check.red          # parse + validate every samples/*.red
red tests/check.red --pdf    # also render each sample to PDF (headless)
```

Both must end with `samples: N passed: N failed: 0`. Run this after any library
change. `red` is the console build (no draw: `DRAW-BG` is skipped with a warning);
`red-view` is the GUI build used to actually view reports.

## DSL invariants (current — do not regress)

- **Widths are explicit**: `px/N` or `ch/N`; never a bare integer. `COLUMN` width is
  `px/N`/`ch/N`/`auto`; its gap is `gap-ch/N` or `gap-px/N`; `IMAGE` width is
  `px/N`/`ch/N`. A float `w.d` is a *number format*, not a width.
- **Path notation only**: `ss/9`, `margin/10`, `link/1`, `border/2`, `gap-ch/2`.
  Legacy `ss-9`/`margin-10`/`#70px` forms are rejected by validation.
- **Arguments are type-matched, not positional** (`IMAGE`, `COLUMN`). A modifier
  carries its optional value as `/N` (`border/2`, `shadow/5`, `gap-ch/4`).
- **Headings**: `h1`/`h2`/`h3` style *and* register TOC entries; `f1`/`f2`/`f3`
  are the style-only equivalents, `f4` resets to base size.
- **IMAGE**: `[IMAGE width? (shadow|border)(/N)? colour? (<|^|>)? source]` with source
  `file!`/`string!`/`image!`; the optional `< ^ >` aligns the image block within the
  content width (or column cell); caption style block is pure text styles.
- **FRAME**: `[FRAME R [items] [draw-ops]]` — the **items block comes first** (it is
  measured, then the backdrop is drawn behind it). Both renderers bind the ops to a
  per-frame env (`x/y/w/h` = padded frame box, `cx/cy/cw/ch` = measured content box);
  the ops' parens are evaluated at render time, so do not pre-compose the report.
- **AT**: `[AT x y [items]]` is an absolute, single-page **overlay** (origin = page
  top-left). Coordinates are deferred to render time with `prev-*`, `cursor-*` and
  `page-*` in scope (two expressions or one pair). AT does not advance the flow or
  update `prev-*`; items are text lines or IMAGE (no DRAW/FRAME/TABLE/PAGEBREAK/
  nested AT), BODY-only, and not allowed inside COLUMN/FRAME. AT images never
  page-break; undeclared widths are contained to the AT width.
- **HEADER/FOOTER** contain text lines only. An in-body `HEADER`/`FOOTER` is a
  running override applied from the **next page onward**.
- **Tokens**: `<page>`, `<pages>`, `<now>` (replaced in header/body/footer). Escape
  a literal one with a backslash: `\<page>`, `\<now>`. For generated text (e.g. a
  `mold`ed source listing) apply that escaping yourself before using it as a value.
- **TOC**: `[TOC [pattern lines]]`; `<hN>`/`<t-page>` placeholders; `link/toc` in a
  pattern style makes entries clickable (View-only jump).
- **Metrics**: a line box is split into true ascent/descent with
  `report-styles/box-ascent-frac`; do not reintroduce “ascent = line-box height”.
  This is what keeps mixed font families on one baseline.
- **PDF**: Base-14 fonts; links/hints, hotspots and `%page-size%` are View-only.
  Images are XObjects: `.jpg/.jpeg` as JPEG (`/DCTDecode`, lossy); PNG/BMP and
  in-memory `image!` values losslessly as zlib `/FlateDecode` RGB (so screenshots,
  text and diagrams stay sharp); `.gif/.webp` use JPEG. Lossless needs an image
  width divisible by 4: Red's `image/rgb`/`argb` accessors shear rows when the
  stride needs 4-byte padding, so unaligned widths fall back to JPEG. Transparency
  is carried as a grayscale `/SMask` (also Flate), fully opaque images get none.
  `pdf-kit` only scans
  `image/argb` for alpha when the source can carry it (in-memory `image!`,
  PNG/BMP/GIF/WebP); JPEG skips the scan — keep it that way, scanning every image's
  ARGB buffer triggers a Red runtime crash once enough images are embedded.

## Generated asset

`samples/110-long-text.red` loads `assets/what-functions.txt`, a **single Red
block** snapshot of Red's function list. It is session-independent on purpose
(calling `what` at render time would list the sampler's globals and change the
page count). Regenerate with the same build used to view:

```bash
red-view assets/utils/make-what-functions.red   # writes assets/what-functions.txt
```

Keep the generator free of function definitions (they would list themselves);
it captures `what` before defining its helpers.

## Conventions / gotchas

- `samples/*-mod.red` are gitignored scratch variants; `tests/check.red` still
  picks them up locally if present.
- Samples use `if exists? %samples/ [change-dir %samples/]`; asset paths are
  `%../assets/...`.
- `tests/check.red` stubs `show-report` (returns `""`) and `alert` (no-op), and
  evaluates each sample with the samples dir as cwd.
- **Do not `compose/deep` the whole report.** `parse-report` already composes the
  template's parens and deliberately defers `DRAW`/`DRAW-BG`/`FRAME` ops; pre-composing
  evaluates the ops' parens (`(as-pair x y)`, `(as-pair page-width margin-top)`) in the
  caller's context, where `x`/`y`/`margin-*`/`page-*` may not exist → “x has no value”.
  Pass the literal block (spec §11.1).
- `show-report` parses **twice** (validate, then render), so every paren runs twice:
  keep builder functions pure and never return a shared literal block that you append
  to — use `copy []` (`res: []` accumulates across calls and duplicates content).
- The `\<` escape marker is stripped by `report-pdf/strip-escape-marker`, byte-aligned
  and only inside `<hex>` text runs. Do not go back to
  `replace/all content (pdf-kit/hex marker) ""`: that strips the literal characters
  `01` from plain numbers too, corrupting any operand containing `01` (e.g. `px/101`).
- Bare words are invalid as line values (except `none`); keywords are recognized
  only as the first element of a block.
- The View renders each page at the display zoom and shows it 1:1; PDF parity is
  checked by rasterizing both when changing metrics.
- Known cosmetic issue: the 1 px TOC link underline can look clipped at a few
  fractional zoom levels (rasterization); accepted, do not “fix” with line gaps.
- Colour shades (`gray0..gray9`, `red0..red9`, …, 13 families, 0 = lightest) are
  defined **globally** at library load by `libs/report-styles.red` (table
  `report-styles/shade-tuples`), so the DSL and raw DRAW use them with no `do load`.
  `assets/color-tuples.red` (generated by `assets/utils/make-colors.red`) mirrors
  the same table for use outside the generator. Do not re-add `do load` in samples.

## When adding syntax

Update all of: parser (arg kinds/validation), both renderers, measurement
(`measure-column-pixels` where relevant), `docs/report-syntax-spec.md`,
`docs/cheatsheet.md`, and add/extend a sample. Then run both check modes.
