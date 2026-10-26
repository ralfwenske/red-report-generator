# Reboot Plan — Clean Report Generator Project

> Status: **planning only, no implementation yet.** Target: start this in a fresh
> session. Read this top to bottom, then `docs/report-syntax-spec.md`.

## 1. Why we are doing this

The current repo grew organically: several overlapping demos, a growing pile of ad‑hoc
tests, a `QUICK-START.md` that has become too long and too loaded, and a path tangle
(`thumbs/` vs `tutorials/thumbs/`, includes that only resolve from a particular cwd).
The library itself is healthy; it is the *packaging and teaching surface* that needs a
reset.

Core insight from the `tutorials/` experiment: **the sample file is the unit of
teaching.** One file = one lesson. The sampler discovers and runs them, so there is no
index to keep in sync and no giant tutorial doc to maintain.

## 2. Vision

- One command to start: `red-view sampler.red`.
- Click a sample in the list → a one‑line `Demo:` goal is shown.
- Double‑click a sample → its source is shown and it runs, so the rendered report appears.
- Adding a lesson = dropping another `.red` file into `samples/`.
- The samples double as the regression fixtures; one headless `tests/check.red` runs
  `validate-report` (and optionally renders PDF) over all of them.
- `libs/` stays small and dependency‑clean; only the 6 library files.

Success measure: a newcomer runs one command, clicks through three samples, and
understands the model in ten minutes.

## 3. Target layout

```
report-generator/
  README.md                # short: what it is, one run command, how to add a sample
  sampler.red              # the single entry point
  samples/                 # one file = one lesson; numeric prefixes set order
    01-hello.red
    02-styles.red
    03-widths.red
    ...
  assets/                  # images shared by samples (e.g. Empress.jpg, ...)
  libs/
    report-parser.red      # parse-report / validate-report / dump-report
    report-styles.red
    report-view.red
    report-pdf.red
    pdf-kit.red
    pdf-fonts.red
  docs/
    report-syntax-spec.md  # the reference (carry over as-is)
    reboot-plan.md         # this document
  tests/
    check.red              # headless parse+validate (optional PDF) over samples/
  LICENSE
```

Placement rules that remove the path tangle:

- `sampler.red`, `samples/` and `assets/` live at the repo **root**; the sampler is run
  from the root (`red-view sampler.red`).
- The sampler resolves its own directory via `system/options/script` and sets the
  working directory accordingly, so it also works when launched from elsewhere.
- Samples reference shared images as `%assets/...`.

## 4. Components

### 4.1 `libs/` — copy unchanged

Copy these six files as‑is; the dependency chain is already clean:

- `report-view.red` → `report-parser.red` + `report-pdf.red`
- `report-parser.red` → `report-styles.red`
- `report-pdf.red` → `pdf-kit.red` (+ `pdf-fonts.red`)

No `libs/` file should reference anything outside `libs/`.

### 4.2 `sampler.red` — harden the experiment

The current `tutorials/sampler.red` proves the concept; the clean version must fix:

1. **Robust header read.** It currently does `select second load to-file f 'Demo`, which
   assumes the second top‑level expression is the `Red [...]` header block. A sample
   without that header silently breaks the description. Enforce the header contract
   (below) and/or read defensively with a fallback.
2. **Filter and sort the list.** `read %samples/` returns OS order and includes
   non‑`.red` files. Keep only `*.red` and sort by filename (hence the `01-`, `02-`
   prefixes).
3. **Default the description.** If `Demo:` is missing, do not set the label to `none`;
   show the filename or `(no description)`.
4. **Never die on a bad sample.** Wrap the double‑click `do` in `try` and show the error
   message in the description label instead of crashing the sampler.
5. **Self‑locating paths.** `change-dir` to the script's own directory (from
   `system/options/script`) so `%samples/` and the samples' `%assets/...` always resolve,
   regardless of the launch cwd.
6. **Read‑only source pane.** The source `area` is for viewing; make it read‑only so it
   reads as source view, not an editor. Keep `Esc` to quit.
7. **Window stacking.** Each `show-report` opens a viewer window; double‑clicking several
   samples stacks windows. At minimum note it in the UI/README; ideally reuse or close
   the previous window.
8. **Requires `red-view`.** The sampler uses `view`/`layout`, so it must run under the GUI
   build; state this in the README and in the sampler header.

Optional nice‑to‑have (only if cheap): a small `Level:`/`Teaches:` field in the sample
header shown next to `Demo:`.

### 4.3 Sample contract

Every sample starts with a Red header so the sampler and a human agree on metadata:

```red
Red [
    Title: "02 — Styles"
    Demo:  "bold, italic, mono, colours and alignment on one line"
    Level: 2
    Needs: 'View
]
```

Rules for a sample:

- **One idea per file.** If it needs "and", split it.
- **Self‑contained and runnable standalone**: include the libs with a path relative to
  the sample file (`#include %../libs/report-view.red`).
- **Filename prefix sets order** (`01-`, `02-`, …); `Demo:` is the lesson's one‑line goal.
- Keep it short enough to read in the source pane.

### 4.4 `assets/`

Move the images the samples need into `assets/` (from the current `tutorials/thumbs/`).
Samples reference them **relative to the sample file** as `%../assets/<name>.jpg`. Avoid
per-sample image folders.

> Correction found during implementation: Red runs a `do`ne script with **that
> script's directory** as cwd (it changes cwd around `do`, then restores it). So a
> sample executed via `do %samples/xx.red` sees cwd = `samples/`, and the original
> `%assets/...` form would resolve to `samples/assets/...`. Sample-relative
> `%../assets/...` works both through the sampler and when run directly
> (`red-view samples/xx.red`); `tests/check.red` switches to the sample's directory
> while rendering PDFs so the same paths resolve there too.

### 4.5 `docs/`

- `report-syntax-spec.md` — carry over unchanged (it is the reference; the line‑width
  model `§5.3/§5.4/§7` is already correct).
- `README.md` — thin: what it is, `red-view sampler.red`, how to add a sample, where the
  spec is.
- Retire `QUICK-START.md`; its best steps become samples.

### 4.6 `tests/check.red` — one headless checker

Replaces the pile of ad‑hoc tests. It should:

- iterate `samples/*.red`,
- load each, run `parse-report` + `validate-report`,
- print a per‑file PASS/FAIL line and a final summary, non‑zero exit on failure if
  feasible,
- optionally render each to a temp PDF (headless, no GUI) behind a flag.

This keeps samples honest and gives CI something to run. Run it with plain `red`
(no GUI).

### 4.7 Line width model (carry over unchanged)

On a line segment the value gets a **box**; the following segment starts at its right
edge. The box comes from, in order: literal `px/N`; else a bare integer or `ch/N` = `N`
average alphabet characters of the segment's style; else a float `w.d` on a number = `w`
average characters with `d` decimals. A **numeric value with a box defaults to
right-aligned** in it (so decimal points line up); strings and other values default left,
and an explicit `<`/`^`/`>` overrides. The average char width is measured per style in
each renderer (`avg-char-width`). Note the implementation details that make it consistent:

- character padding of numbers is disabled for line segments
  (`format-number-value/nopad`);
- table cells keep their own column-based formatting and must **not** receive a box, so
  floats are stripped from the cell's *text* styles before rendering;
- `px/N` and char/floats both align following segments; chars/floats are the memorable
  choice when values share a style.

Reference: `docs/report-syntax-spec.md` §5.3/§5.4.

## 5. Lesson ladder

Start with **01–03 only**; extend later by dropping files in.

| # | Sample | Teaches |
|---|---|---|
| 01 | `01-hello.red` | `BODY` + one line — the minimum viable report |
| 02 | `02-styles.red` | bold/italic/underline/mono, colours, alignment on one line |
| 03 | `03-widths.red` | char widths vs `px/N`; making a column of values line up |
| 04 | `04-sections.red` | `HEADER`/`BODY`/`FOOTER` + tokens `<page>`/`<pages>` |
| 05 | `05-table.red` | `TABLE BOX ALT`, header row, page splitting |
| 06 | `06-column.red` | `COLUMN` `auto` vs `ch`/`px`, rows from a variable |
| 07 | `07-image.red` | caption, width in style, `shadow`/`border`, `link/N` |
| 08 | `08-paper.red` | sizes, `landscape`, margins |
| 09 | `09-links.red` | `link/N`/`hint/N` + `do-popup` callback |
| 10 | `10-your-data.red` | computed rows spliced in + `report-pdf/generate` |

Sketch of the first three (content only, to be written during implementation):

- **01-hello** — the smallest block that renders: `[BODY [["Hello World" [h2]]]]`,
  include + `show-report`.
- **02-styles** — one line showing each style and colour; a couple of lines to show
  alignment (`<` `>` `^`).
- **03-widths** — the tutorial you just built: several lines whose first value uses a
  char width (`20` / `ch/20`) so like‑styled following values line up, plus one line
  using `px/N` and a note that mixed styles need `px/N`. Include a numeric value with a
  float style (e.g. `1234.5678 [i 15.2]`) to show the same box via the float's integer
  part, with the fraction as decimals and the number right‑aligned.

## 6. Migration steps

1. Create the new clean repo (or a clean branch/dir); add `LICENSE` and a thin `README.md`.
2. Copy the six `libs/` files unchanged. Verify `report-view.red` loads headless.
3. Add `sampler.red` at the root and harden it per §4.2; copy the needed images into
   `assets/`.
4. Add the sample template and write samples `01`–`03`; run each from the sampler.
5. Add `tests/check.red`; make it cover every sample (parse + validate).
6. Move `report-syntax-spec.md` and this plan into `docs/`.
7. Only then port anything else worth keeping from the old demos into `samples/`
   (`Test-Report.red` is the richest; mine it for the table/column/image/interaction
   lessons). Retire the rest.
8. Archive the old repo (tag/`README` note) so the reboot is traceable.

## 7. Decisions / open questions to settle tomorrow

- **Sampler chrome:** keep the source pane, or show description only and open a separate
  window? (Current: source pane — keep, it helps learning.)
- **Window reuse:** is one viewer window reused on each double‑click, or is stacking
  acceptable for v1? (Recommend accept for v1, note it.)
- **`Level:` vs plain order:** is numeric `Level:` needed, or do filename prefixes
  suffice? (Recommend filename prefixes; keep `Level:` optional.)
- **PDF in `check.red`:** validate‑only or also render? (Recommend validate first, PDF
  behind a flag.)
- **New repo or clean branch:** new repo is cleanest; a branch keeps history easier.
  (Recommend new repo, with a note/tag in the old one.)
- **License** for the new project.

## 8. Definition of done for the first implementation session

- Clean tree exists exactly as in §3.
- `red-view sampler.red` (from the repo root, and from another cwd) lists samples in a
  deterministic order, shows the `Demo:` line, and double‑click runs the sample.
- A deliberately broken sample shows an error in the UI and the sampler keeps running.
- `red tests/check.red` runs headless and reports PASS for every sample.
- Samples `01`–`03` are written, minimal, and each teaches exactly one idea.
- `README.md` is short and tells a newcomer the one command to run.
- This plan's open questions (§7) are resolved or explicitly deferred with a note.

## 9. Pitfalls to remember

- Red `#include` resolves **relative to the including file**; data paths (`%assets/...`)
  resolve **relative to the working directory** — hence the sampler self‑locates.
- The sampler must run under `red-view` (GUI), the checker under `red` (headless).
- Do not reintroduce a giant markdown tutorial; the sampler *is* the index.
- Keep samples tiny; if a lesson needs a page of prose, it is two lessons.

## 10. Decisions taken (implementation session)

§7's open questions are settled as follows:

- **Sampler chrome** — the source pane is kept (it helps learning) and is
  read-only. Red 0.6.6 has no `read-only` facet on `area`, so it is a `disabled`
  area (no editing, still displays); Esc is a window-level `on-key`, with a Quit
  button as the guaranteed fallback.
- **Window reuse** — v1 opens a fresh viewer window per double-click; `show-report`
  blocks until that window is closed, so windows do not stack. Noted in the
  sampler and the README.
- **`Level:` vs order** — filename prefixes set the order; `Level:` is optional and,
  when present, is shown next to the `Demo:` line.
- **PDF in `check.red`** — validate first; PDF rendering is behind `--pdf`.
- **Repo** — this directory is the clean repo; the predecessor
  (`../report-generator-2`) is kept for history.
- **License** — MIT (assumed; edit `LICENSE` if another license is preferred).
- **Validation location** — `show-report` now runs `validate-report` itself
  (spec §12, recommendation P4 #11). It opens a window only for a valid report and
  returns `""` after that window closes, or the problem message (no window) when
  invalid. Samples therefore stay minimal — no per-file validation boilerplate —
  and the sampler distinguishes "invalid" from "opened and closed".
- **IMAGE width** — the width belongs to the image, so it is the optional **first
  argument** (`[IMAGE 120 %file …]`, bare number = px; `px/N`/`ch/N` also accepted).
  The parser already validated this form, but both renderers were only reading a
  `px/N` from the caption style block, so the argument was silently ignored; the
  renderers now honour the argument (caption `px/N`/`ch/N` remains as a fallback).
  `libs/report-styles.red`, `libs/report-view.red` and `libs/report-pdf.red` changed
  for this.
- **Global base font** — `make-font styles size` (e.g. `report-view/make-font [m] 8`)
  sets the report's base font: style words plus a size. It is defined in
  `report-styles` (so both renderers inherit it), applies as the outermost style
  layer in `parse-report`, keeps `report-styles` in sync for the parser, and
  recomputes `line-height`. Headings now scale from the base size (2× / 1.5× /
  1.17×, preserving 24/18/14 at the 12 pt default). The old internal font builder
  was renamed `build-font`; the parser injects `report-styles/base-styles`.
  `make-font` now configures the View, the PDF and `report-styles` in one call, so
  a single call before rendering keeps column widths and pagination consistent
  (previously the PDF kept its default size and could fit fewer columns). The PDF
  uses Base-14 fonts only (mono = Courier). The View's families were aligned to the
  PDF's base-14 metric clones (`Times New Roman` / `Helvetica` / `Courier`) and its
  sizes are rounded to whole points (GTK renders whole-point sizes only; fractional
  sizes collapsed the heading/body distinction). Because the View renders ~1.3×
  wider per point and the three faces differ slightly, the parity scale is set
  **per family**: View `font-scale-serif/-sans/-mono` (an early calibration used
  `0.84`; current View scales are `1`) and PDF `font-scale-*`/`line-scale-*`
  (platform-selected; see spec §12 for the current Windows/Linux/macOS values).
  Six numbers per family are tuned for closest serif/sans/mono parity.
- **Rendering no longer mutates the parsed report** — `format-pair-value` expanded
  `<now>` with an in-place `replace/all`, so the first render rewrote the parsed
  string. Rendering the same page-obj again (View then PDF, or two PDFs) then
  measured/rendered the date-expanded text: a 62-char line became 74 chars, which
  silently dropped a `COLUMN` from two columns to one at 10 pt. Fixed by copying
  before replacing (`replace/all copy val …`).
- **Validation is the single gate** — `parse-report` is now side-effect free (it no
  longer `print`s "Failed to parse page structure"); `validate-report` does a cheap
  structural pre-scan of the raw page (unknown section keyword, bare word, bad paper
  directive, unknown style word/lit-word, unknown `!X` negation) plus the existing
  per-section checks, and reports the first problem as a message. `show-report`
  already calls it first, so invalid input is reported instead of printing to the
  console; the parser can assume validated input.
- **Word wrapping** — BODY text lines wrap to the content width by default (long string
  values break at spaces, keeping their style; numbers/width-boxed segments are atomic;
  long single words are hard-split; `nowrap` opts a line out). **Explicit newlines in a
  string are honoured as hard breaks** (so a multi-line `{...}` value renders as
  separate lines — previously the View drew them as one command and only advanced one
  line height, overlapping). It is done in each renderer via a shared
  `report-styles/wrap-line` taking a measure callback (`report-view/line-measure` with
  `measure-text`, `report-pdf/line-measure` with `pdf-kit/text-width`), because the
  available width is the page/popup width (known only to the renderer — `show-popup`
  sets it on the viewer) and accurate breaks need real font metrics.
- **Measured line geometry (final)** — superseded the size×`line-height-factor`
  model (and its `line-height-factor-large` second knob) with metrics-based layout.
  Each renderer supplies `text-metrics text styles -> [width height ascent]`
  (`view-metrics` via `size-text`, `pdf-metrics` via Base-14 metrics); shared helpers
  `line-ink`/`line-step`/`line-advance`/`footer-height`/`row-height` take that
  function explicitly (Red calls a function-valued word passed as an argument, so it
  is always passed as `:metrics` or copied via `get/any`). A line's height is the
  largest measured height among its values; baselines step by
  `descent(prev) + line-gap-px + ascent(next)`, so line boxes just touch with a
  configurable `report-styles/line-gap-px` (default 1), and each background/frame box
  is the value's own measured box — which is what removed the heading/cell overlap.
  `prev-line` carries the previous line across body calls and after the header, and
  is cleared on page breaks and after tables/images/columns.
  Remaining: column auto-width and `ch/N` still use the conservative
  `font-size * 0.583` estimate (`report-view/col-char-width`,
  `report-styles/measure-column-pixels`) rather than the metrics function, so mono
  cells can differ from the drawn text width.
- **Intrinsic images fit the remaining space** — an `IMAGE` with no width argument
  is scaled to the space still free on the current page (contained to the page
  width and the remaining height) instead of the full content height, so it no
  longer forces a page break when text precedes it; put it first in the body for a
  full-page image. A declared width still starts a new page if needed.
- **Image captions keep the normal text size** — `link/N`/`hint/N` ids were being
  read as `word/N` size suffixes (`link/1` → size 1), shrinking captions (and any
  link/hint text) to ~1 pt. `style-size` now only accepts a known style word or
  family as the base, so ids are ignored; a caption can still set its own size with
  any `/N` style word (e.g. `[s/8]`, `[m/10]`). The reserved caption height follows
  the caption's size. The same vocabulary is accepted in a `COLUMN`'s `image […]`
  clause (and in the column args), so e.g. `image [shadow 3 silver s/8]` sizes
  every image caption in that column.
- **Heading line height** — a line's vertical slot is now
  `max(line-height, largest heading size)` via `report-styles/line-advance`, used
  by the header, footer and body in both renderers (and `footer-height` reserves
  the footer's real height). Previously a 24 pt `h1` line advanced by `line-height`
  only (16–18 px), so the next line touched its descenders — visible in a header
  like `["ACME Corp" [h1 !m red] …]`. The factor alone could not fix this.

So `libs/` is no longer byte-identical to the predecessor: `report-styles.red`,
`report-view.red` and `report-pdf.red` carry the fixes above.

- **`DRAW-BG`** — an optional raw Red/View draw block (`[DRAW-BG density? [draw…]]`,
  spec §3.1) painted behind every page. `report-parser.red` parses it into
  `pg/draw-bg` (`args`, `lines`) and validates the optional integer density.
  `report-view.red` appends the composed block to every page's draw block;
  `report-pdf.red` rasterizes it once with `draw-works?`/`render-draw-bg` and stamps
  the resulting JPEG XObject onto every page. Parens are evaluated by the renderer
  against the page geometry (`page-width`, margins), so the sample must *not*
  pre-compose the block. Three findings shaped this:
  - headless console Red has a `draw` word that silently **no-ops**, so capability is
    probed by drawing a 4×4 test image and checking the pixel changed;
  - `draw`'s `scale` command does not scale reliably in this build, so the PDF path
    rasterizes at page resolution and upscales with `draw [image src 0x0 size]`
    (the density argument controls that upscale);
  - `pdf-kit` embeds JPEG only (no alpha/`/SMask`), so there is no transparent
    `DRAW-FG` and no vector translation of draw output.
- **End whitespace is preserved** — `wrap-line` used to keep space/tab runs only as
  leading indentation, dropping trailing ones, so a background color
  (`["  xyz  " [black yellow]]`) stopped at the visible glyphs. Trailing runs are now
  kept verbatim while still being excluded from the wrap decision; runs *between*
  words stay normalised to a single space. `size-text/with` (View) and the PDF metrics
  both count the spaces, so the background box grows to match.

Also learned while implementing: Red changes the working directory to the
top-level script's own directory, so the sampler's `%samples/` resolves from any
launch cwd; `check.red` (in `tests/`) moves up one level to the repo root.
`load` leaves `#include` directives in the block (they are resolved when the
block is `do`ne), so `tests/check.red` strips them and stubs `show-report` to
capture each sample's report block headlessly.

