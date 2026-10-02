# Report Syntax Specification

| | |
|---|---|
| **Status**        | Adopted baseline — describes the syntax *as implemented* in this repository |
| **Version**       | 2.0 |
| **Date**          | 2026-08-29 |
| **Supersedes**    | `pdf-reports/new-syntax-proposal.txt` (draft, v1) |
| **Applies to**    | `libs/report-parser.red`, `libs/report-styles.red`, `libs/report-view.red`, `libs/report-pdf.red` |
| **Verified**      | Headless Red run (2026-08-29): all three demo reports (`Test-Report.red`, `Simple-Report.red`, `Long-Report.red`) parse and pass `validate-report`; style semantics spot-checked |
| **Next step base**| Section 13 (divergences) and Section 14 (recommendations) |

---

## 1. Scope and design goals

This document is the formal specification of the *compact report dialect* used by
report-generator-2. A report is described by a single Red block; one parser
(`parse-report`) converts it into a structured object that two independent
renderers consume with identical results:

- **View renderer** (`report-view.red`) — interactive, multi-page window using Red's `draw` dialect.
- **PDF renderer** (`report-pdf.red`) — a self-contained PDF generator (JPEG image XObjects, embedded fonts, xref table).

Design goals of the dialect:

1. **Declarative and compact** — a report page is data, not code.
2. **Single source of truth** — one page description drives both renderers.
3. **No collision with Red syntax** — reserved keyword words (`HEADER`, `TABLE`, …) are bare words in a block, or unambiguous tokens.
4. **Styles are per-value** — every value on a line carries its own optional style block; an optional first block contains line-wide styles.

## 2. Notation

The grammar below uses:

- `[ … ]` — a Red block literal (syntactic grouping).
- `( … )` — optional, or a Red parenthesized expression to be evaluated (see §11).
- `x | y` — alternatives. `*` — zero or more. `+` — one or more.
- Keywords are shown uppercase for readability; matching is **case-insensitive** (verified; see §11.3).

## 3. Document structure

A report page description is a block: an optional *paper clause* (leading words/pair),
then the items. Three of those items are the *sections* — keyword items whose items
block becomes that section:

```text
page        := [ paper-clause? item … ]        ; paper clause, then items in any order
paper-clause := paper-size? orientation? margin? …
paper-size   := a4 | letter | legal | a3 | a5 | <WxH pair>   ; default a4
orientation  := landscape | portrait                          ; default portrait
margin       := top-N | bottom-N | left-N | right-N | margin-N   ; N in points, default 50

section-item := [HEADER [items]]            ; optional
              | [BODY   [items]]            ; required
              | [FOOTER [items]]            ; optional
              | [DRAW-BG density? [draw…]]  ; optional raw page background (§3.1, §16)

item         := … | [DRAW H? [draw…]]         ; BODY-only foreground art (Advanced, §16)
```

- `BODY` is **required**; `HEADER` and `FOOTER` are optional and may appear in any order.
- The paper clause sets the page's size, orientation and margins for **both** renderers
  (default a4 portrait, 50 pt margins). Directives may be combined in any order
  (`[landscape a4 top-20 margin-15 …]`, `[600x800 portrait right-10 …]`); when repeated,
  the last size and last orientation win. For margins, `margin-N` sets a uniform default
  for all four sides and an individual `top-N`/`bottom-N`/`left-N`/`right-N` always overrides
  it — in **any order** (`[margin-25 top-10 …]` and `[top-10 margin-25 …]` give the same result).
  A **pair** (`600x800`) sets a custom
  width×height in points; margins are in points too (`top-20`, `right-10`, `margin-25`
  sets all four). Unknown leading words are invalid (reported by `validate-report`).
  All four margins measure from the page edge to the **top of the first line** (header
  if present, else the first body line), so the visual top gap equals `margin-N` just
  like the other sides.
- Words between a section keyword and its items block are section *args*: parsed and
  stored (`pg/header/args` etc.) but **currently unused by either renderer** (§13).

Example:

```red
report-source/build-report: compose/deep [
    [HEADER [
        ["ACME Corp" [h1 red] "Sales Report" [h2] (now) [date green]]
        ["Page <page> of <pages>" "" (now) [time]]
    ]]
    [BODY [
        ["Hello World" [h2]]
        ["Today is " (now) [i u b date]]
    ]]
    [FOOTER [
        ["  Confidential  " [b] "Page <page> of <pages>"]
    ]]
]
```

### 3.1 DRAW-BG — raw page background

`DRAW-BG` paints a raw Red/View **draw dialect** block behind `HEADER`, `BODY` and
`FOOTER` on **every** page:

```red
[DRAW-BG 3 [
    pen off
    fill-pen 238.242.255
    box 0x0 (as-pair page-width 46)
]]
```

- The block after the keyword is the draw dialect, verbatim. It is painted after the
  page's white background and before all other content, so whatever it draws sits
  behind the text.
- An optional integer before the block sets **pixel density** (clamped to 1–8,
  default 3), used only by the PDF renderer to reduce jaggies; higher is sharper but
  larger. It is ignored by the View renderer.
- Parenthesised expressions inside the block are evaluated **once** at render time,
  with the page geometry in scope: `page-width`, `page-height`, `margin-left`,
  `margin-right`, `margin-top`, `margin-bottom`. Built-in functions work as usual.
  Because the renderer performs this evaluation, do **not** wrap the block in your own
  `compose/deep` — the parentheses must survive until rendering.
- The block may use anything the View draw dialect supports (`box`, `line`, `circle`,
  `text`, `image`, `polygon`, `spline`, …). Text painted here is rasterized for PDF
  output: it is not selectable text.
- **Headless limitation.** The draw dialect rasterizes only under a GUI-capable Red
  (`red-view`). Building a PDF with the plain console `red` omits the background and
  prints a warning; the View window always shows it. `red tests/check.red --pdf`
  therefore skips `DRAW-BG` for this one sample.
- There is an inline foreground counterpart, `[DRAW H [draw…]]`, described in the
  Advanced usage section (§16). Unlike DRAW-BG it is rendered as **native vector**
  by both renderers (no raster, works headless), which is why it draws a restricted
  subset of the dialect.
- **Composing the report.** No `compose/deep` is needed: `parse-report` composes the
  template's parens for you, and DRAW-BG's (and DRAW's) ops block is deliberately left
  uncomposed so its parens (`(as-pair page-width 56)`) are evaluated at **render** time
  with the page geometry in scope (§11.1, §16.7).

`DRAW-BG` applies to all pages. To decorate a single page, draw oversized art on a
one-page report (raw draw is not clipped to the text margins).

## 4. Items

Every item is a block. Its first element decides the shape — a *known word*
makes it a keyword item, anything else makes it a *line*:

```text
item        := keyword-item | line-item

keyword-item := [ known-word args… [items]? ]   ; trailing items block optional
known-word   := HEADER | BODY | FOOTER | TABLE | COLUMN | IMAGE | PAGEBREAK | DRAW | FRAME
args         := values up to the first block (words, numbers, files, issues, …)

line-item    := [ value style-block? value style-block? … ]
```

- The parser collects *args* up to the first block; that block (if present) is the
  *items* block, parsed by the same rule. `[IMAGE 60 %logo.png]` and `[PAGEBREAK]`
  are therefore valid — the trailing `[]` is optional.
- Keywords are case-insensitive **bare words** (`TABLE`, `BODY`, …); a quoted `'TABLE` also
  works — the parser normalizes both (verified).
- **Bare-word collision (documented):** a line whose first value is a bare word equal
  to a known keyword is parsed as a keyword item. Values are normally strings,
  numbers, dates, or parens, so this is rare; to start a line with a literal word,
  write it as a string: `["table" …]`.
- **Container style args.** Sections (`HEADER`/`BODY`/`FOOTER`) and `TABLE` accept style
  words as args; they style the whole container and its contents. The style inherits
  down: a section style reaches every line, table row/cell and column cell inside it;
  a table style reaches its rows/cells. Each deeper level merges on top (decorations
  add; the deeper value wins on colors/alignment/format/width/family). Examples:
  `[BODY b [ … ]]`, `[TABLE b BOX ALT [rows]]`.
- **Negation `!X`.** Any style may carry `!b`/`!i`/`!u`/`!m`/`!s`/`!<`/`!>`/… which drops
  that attribute inherited from **all** higher levels. E.g. a row `[[!b] …]` inside a
  bold table renders not bold.

### 4.1 Line items

`[ value style-block? value style-block? … ]`

- A *value* is any Red literal: `string!`, `number!`, `date!`, `tag!`, `issue!`, … (`none` → empty).
  To insert a computed value use a **paren**: `(now)`, `(total)`, `(backup-date)` — evaluated by
  `compose/deep` at build time (§11). A bare `word!` is stored as-is and rendered literally, so
  compute values with parens.
- The *style-block* immediately following a value applies to that value only and is
  optional; it must not itself contain `string!` or `block!` values (that is how the
  parser tells a style block apart from a nested line).
- A **leading style-block** as the line's first element applies to *every* value on the
  line; a value's own style-block is **merged on top of it** — decorations like
  `b`/`i`/`u` add, and the value wins on colors, alignment, format, width and font
  family. Example: `[[b red] "Total" "Δ" [i] 5123.88 [money]]` — bold red "Total",
  bold-italic red "Δ", and a bold-red money number. Works for table rows and column
  rows too.
- A single-segment line is rendered left-aligned; a multi-segment line flows
  segments left-to-right from the left margin. Segments are joined on one line —
  **there is no word wrapping** (§13).
- An **empty line block `[]` is a blank line**: it parses exactly like `[""]` and
  advances one line height. Use `[]` (or `[""]`) as a spacer between items.

### 4.2 Table items

`[TABLE (BOX) (ALT) [rows]]`

- The **first row of `rows` is the header row**: it is rendered with a gray fill and
  bold text, and its style blocks define the *column specification* (§6).
- The remaining rows are data rows. A data row is a line item whose segments map to
  columns positionally; missing cells render empty.
- Modifiers, in any order:
  - `BOX` — draw the outer table border and vertical rules between columns.
  - `ALT` — shade every second data row (`alt-row-gray`).
- Rows may contain page-break items (`[PAGEBREAK]` or `[PAGEBREAK n]`); the table
  then continues on a new page and the **header row is repeated**.
- **A table splits across pages like a COLUMN**: the header row and as many rows as fit are
  drawn, then on the next page the **header row is repeated** and the remaining rows continue.
  Only if even the header + first data row cannot fit is the whole table moved to a new page.

### 4.3 Column items

`[COLUMN width? gap? [ rows]`  |  `[COLUMN width? gap? image [img-styles] [ rows]`

- *width* — column width: a bare number (in `ch` units, see §7), an explicit unit
  tag `#Npx` / `#Nch`, or `auto` to auto-measure the widest row. Omitted → `auto`.
  (Unlike `IMAGE`, whose bare width argument is px — §4.4.)
- *gap* — space between columns: bare number in `ch`, or `#Npx`/`#Nch`; default `1ch`, minimum `1ch`.
  **`gap` cannot be set unless `width` is present** — the first arg is always the width.
  To set only the gap, give `auto` as the width: `[COLUMN auto 2 …]`.
- *text (line) styles* — any additional args after `width`/`gap` apply to **line rows only**:
  `m`, `s`, `b`, `i`, `u`, `h1`/`h2`/`h3`, `link-N`/`hint-N` (make every cell
  interactive), color words (font colour for text), and negations (`!b` …). Useful to pin a font
  (e.g. `m`) so column widths are predictable. They never touch a contained `IMAGE`.
  Example: `[COLUMN auto 1 m rows]`.
- *image clause* — the word `image` followed by one style block styles every contained `IMAGE`
  (and only images): `[COLUMN … image [img-styles] [rows]]`. The image style block uses the IMAGE
  grammar from §4.4, including caption text styles — so a **family and/or size** applies to all
  the column's image captions, e.g. `image [shadow 3 silver s-8 link-1]`. It may carry a
  **default image width** (`#Npx`/`#Nch`, e.g. `image [#80px shadow 3 silver]`). Generics and
  the image clause may both be present (`[COLUMN b image [#80px shadow 3 silver] rows]`): text
  rows get `b`, images the image styles.
  With **no** `image` clause a contained image falls back to its **own** caption style block.
- Rows may be line items or image items. Line rows get the text styles; image rows are styled
  solely by the `image` clause or their own caption. **Contained image widths are ignored** —
  the column widths them via the image clause / column width.
- Rendering: rows are distributed **balanced across as many columns as fit the page
  width**, height-aware, and continue on new pages when the remaining rows do not fit
  (§8). **Image rows in a column share one row height = the max contained image height** (so
  varying source sizes line up). Columns are top-aligned; the page advances by the tallest column.
- Nested columns and tables inside columns are **not supported** (§13).

### 4.4 Image items

`[IMAGE width? file]`  |  `[IMAGE width? file [caption [styles]]]`

- *file* — a `file!` or `string!` path.
- *width* — optional first argument, **belonging to the image** (not the caption): a bare
  number is pixels (see §7), or `#Npx` / `#Nch` for an explicit unit. When omitted the image
  is scaled to its **intrinsic proportions, contained to the space still free on the current
  page** (so it fits under preceding text instead of forcing a page break); put it first in
  the body for a full-page image. Inside a `COLUMN` a width-less image is contained to the
  column width (see §4.3).
  For backward compatibility a `#Npx` / `#Nch` at the start of the caption style block is
  also honoured as a fallback when no width argument is given.
- The optional trailing block is the image's **caption line** — exactly one value + a style block.
- *caption* — a `string!`, drawn **centered one line below** the image. When the caption line is
  omitted, the caption defaults to the **file's name without extension** (`Empress.jpg` → `Empress`);
  a `""` value gives **no caption**.
- *styles* (the caption's style block) — IMAGE-specific grammar, in order:
  1. optional `shadow` or `border` — `shadow` = drop shadow (base and image the same size, the
     base offset down-right); `border` = a frame box;
  2. optional **integer** — the inset / offset in points (**defaults to 5% of the image width**);
  3. optional **color** — the shadow/border colour (default `silver`); the **first** colour after
     `shadow`/`border` is consumed as the box colour;
  4. the remaining words are the caption's **text styles** (`b i u s`/`ss`/`m` `h1-h3`, any
      `-N` size such as `s-8`/`m-10`, `link-N`, `hint-N`, `!X`) and the trailing 1–3
      **colours** (font, background, frame) — as on a line. The caption keeps the normal
      text size unless its style block sets one.
      `link-N`/`hint-N` make the **whole image area** an interactive hotspot (the caption is the
      popup text, `N` the id); `link-N` implies a solid underline, `hint-N` a dotted one (View-only).
- Examples:
  - `[IMAGE %Empress.jpg]` — intrinsic width contained to the page; caption `Empress`.
  - `[IMAGE 120 %Empress.jpg ["Empress" [shadow 3 red link-1]]]` — 120 px, red shadow, linked.
  - `[IMAGE #120px %Empress.jpg ["Empress" [border 3 silver]]]` — explicit px unit, silver frame box.
  - `[IMAGE %Empress.jpg ["Empress" [b red blue]]]` — intrinsic width, no box; bold caption, red on blue.
  - `[COLUMN #120px #4ch image [shadow 3 silver] [ [IMAGE %a.jpg] [IMAGE %b.jpg [""]] ]]` — a column
    of images, silver shadow, uniform row height; captions default to the file name, the second has none.
- Height derives from the image's aspect ratio; the base extends the occupied height.
  Works in both renderers, including inside a `COLUMN`.
- PDF output embeds images as **JPEG XObjects** (any loadable image is converted to
  JPEG; the View renderer loads images natively; links/hints are View-only).

### 4.5 Page-break items

`[PAGEBREAK]` — force a page break.

`[PAGEBREAK n]` — break only if fewer than `n` lines fit in the remaining space
(conditional break).

## 5. Styles

A *style-block* is a block of styles applied to the preceding value:

```text
style-block := [ style … ]
style       := alignment | decoration | format | width | color | interactive
```

Style words are written **bare** in reports (`[b]`, `[i]`, `[u]`, `[h1]`, `[date]`,
`[money]`). The quoted forms (`'b`, `'date`, …) are equivalent, but bare is canonical and
is what the demos use. Alignment words (`<` `>` `^`) are the exception — they read better bare

### 5.1 Alignment

| Style | Meaning | Contexts |
|---|---|---|
| `<` | left-align | line segments, table columns (default everywhere) |
| `>` | right-align | line segments, table columns |
| `^` | center-align | line segments, table columns |

The **default alignment is left**, with one exception: a **numeric value that carries a
width box** (`w.d` float, integer `N`, `#Nch`, `#Npx`) defaults to **right**, so numbers
and their decimal points line up. An explicit `<`/`^`/`>` always wins. (The original
proposal suggested "center if no alignment given" — *not* adopted; `'^` was kept. See §13.)

### 5.2 Decoration

| Style | Meaning |
|---|---|
| `b` | bold (implied by `h1`–`h3`) |
| `i` | italic |
| `u` | underline |
| `!u` | negate underline — suppresses `u`, and the automatic underline implied by `link-N`/`hint-N` |
| `s` | serif font (the default) |
| `ss` | sans-serif font |
| `m` | monospace font (widths are `length × cell advance`, independent of font ligatures, so the View and PDF agree) |
| `h1` / `h2` / `h3` | heading levels, font sizes 24 / 18 / 14 pt |
| `word-N` | any style word may carry a `-N` size suffix (points), e.g. `i-8` (italic 8), `m-10` (mono 10), `ss-12` (sans 12), `h2-20`; it sets that value's font size, or the whole line when used in the line's leading style block |

### 5.3 Value formatting

| Style | Meaning |
|---|---|
| `money` | `$` + thousands separators + 2 decimals; negatives as `-$n.nn` |
| `s1000` | thousands separators, no decimals |
| `10.3` (float) | number format: `3` decimals, and on a line segment the width `10` is a box of 10 average characters (see §5.4); a numeric value with a box defaults right-aligned |
| `date` / `time` / `datetime` | format a `date!` value as date / time (`hh:mm`) / date+time. Use `(now) [date]` / `(now) [time]` / `(now) [datetime]` |
| `N` (integer) | **per-value width** — a box of N average characters of the segment's style (see §5.4) |
| `#Npx` | literal N-pixel per-value width (see §5.4) |
| `#Nch` | N average characters of the segment's style, like the integer form (see §5.4) |
| `blank` | in table cells: suppress `0` numeric values |

Note on the float form: a negative width (e.g. `-10.3`) is parsed but has **no
effect** — the proposal's "negative width = right-align" rule was never implemented;
use `'>` instead (§13).

### 5.4 Widths on a line segment

A width on a line segment defines a **box** for that value; the value is laid out in
the box honouring its alignment, and the next segment starts at the box's right edge.

- `#Npx` — a literal N-pixel box.
- integer `N`, or `#Nch` — a box of `N` **average characters of the segment's
  style/font**. The average is measured once over the alphabet `a`–`z` `A`–`Z` in
  the resolved style (font family, size, weight, italic), so it depends only on the
  style, **not** on the value's own text. Two segments sharing a style therefore get
  the same box for the same `N`, which makes a column of following values line up.
- float `w.d` on a number — the same box, using the **integer part** `w` as the
  character count, with `d` decimals in the formatted number.
- If the text is wider than the box, the text wins (no truncation) and the cursor
  advances past it.

A **numeric** value with any of these boxes defaults to **right** alignment in its box
(so decimal points line up); other values default to left, and an explicit `<`/`^`/`>`
overrides in every case.

| Context | Width means |
|---|---|
| line segment (content/header/footer), integer `N` or `#Nch` | N average alphabet characters of the segment's style |
| line segment, float `w.d` on a number | average-character box of size `w`, `d` decimals |
| line segment, `#Npx` | N literal pixels |
| table header row cell | column width in `ch` units |

The integer-vs-column dual meaning is the largest source of confusion in the dialect
and should be revisited (§14, R4). On a line, `#Npx` and the style-relative
`N`/`#Nch` forms both align following segments; `N`/`#Nch` is the memorable choice
when the values share a style.

### 5.5 Colors

Colors are the **last styles in the block** and may be given as:

- a tuple: `255.165.0` (RGB);
- a word resolving (in the **global** namespace) to a tuple — Red's predefined
  color words (`red`, `blue`, `green`, `yellow`, `black`, `white`, `gray`,
  `purple`, …) or any user-defined global tuple word.

Tuple position defines the role (1st = font color, 2nd = background, 3rd = frame/border):

```red
["text" [b 255.0.0 0.128.0 10.10.10]]   ; bold red text, dark-green bg, gray frame
["text" [h1 red]]                       ; heading, red font
```

### 5.6 Interactive styles (View renderer only)

| Style | Meaning |
|---|---|
| `link-N` | clickable hotspot; on click calls the popup handler with `'link N text` |
| `hint-N` | hover hint; after the hint delay calls the handler with `'hint N text` |

A `link-N` style implies a **solid** underline, a `hint-N` style a **dotted** one,
automatically — unless `!u` is present (which suppresses the underline). An implicit
auto-underline is also **not drawn when the run has an opaque background** (the
background already marks the run, and with a 1 px row gap the underline would land in
the next row's box); an explicit `u` is always drawn.
These auto-underlines are **View-only**: the PDF drops links/hints entirely and so does
not auto-underline them (an explicit `u` still underlines — including over a background).

The handler signature is `func [type [word!] id [word! number!] text [string!]]`
(Red 0.6.6 has no distinct runtime `lit-word!` — `'link`/`'hint` arrive as `word!`,
so a `[lit-word!]` parameter rejects them).
The **PDF renderer silently drops** links and hints (§13).

### 5.7 Word wrapping (BODY text lines)

BODY text lines wrap automatically at the content width
(`page width − left/right margins`). A **long string value** is broken at spaces into
several visual lines, each keeping the value's style; indentation (leading spaces) is
kept on the first line and long single words are hard-split. Other values (numbers,
dates, `<now>` etc.) and width-boxed segments are **atomic** — they move whole to the
next line if they do not fit, and a single value cannot be split.

- Wrapping is done by each renderer with **real font metrics**, so it fits the actual
  page (and the View's/PDF's own font size/scale). The View and PDF may therefore
  break at slightly different points — each fits its own page.
- **Explicit newlines** in a string value are honoured as hard line breaks (a multi-line
  `{...}` string renders as separate lines, each advanced by the line height).
- Only top-level BODY text lines wrap; tables, columns, images, header and footer are
  unaffected.
- `nowrap` (as a line/value style) disables wrapping for that line; `wrap` is accepted
  as an explicit no-op. Example: `["a long sentence …" [h3 nowrap]]`.
- **Whitespace is significant at the ends of a value.** Leading and trailing space/tab
  runs are kept verbatim, so a background color (the second tuple in a style block)
  extends over them: `["  xyz  " [black yellow]]` paints the whole padded run. Runs
  *between* words are normalised to a single space for wrapping, and trailing runs do
  not count toward the wrap decision (they never push a word to the next line).

## 6. Tables — column specification

The header row's style blocks configure each column:

| Header style | Column effect |
|---|---|
| `<` / `>` / `^` | column alignment (default left) |
| integer `N` | column width in `ch` units (default `12ch`) |
| `money` / `s1000` / float `10.2` | default number format for the column |
| `b` | bold column values |
| `blank` | suppress `0` values in this column |

Data rows may override per-cell: the cell's own style block is merged with the column
defaults (column `b` is inherited; the first tuple is used as the cell's font color;
`blank`/`s1000`/`money` are honored from either source). Alignment/format from
the column spec win unless overridden by `<`/`>`/`^` in the cell.

## 7. Units

| Tag | Meaning |
|---|---|
| bare number in a table header | column width in `ch` |
| bare number in `COLUMN` width/gap | `ch` |
| bare number in `IMAGE` width | `px` |
| `#Npx` | `N` pixels |
| `#Nch` | `N` × 0.583 × `font-size` pixels |

`1ch ≈ 0.583 × font-size` (a conservative estimate; default 12 pt ⇒ 7 px). Note the asymmetry: COLUMN uses
`ch` by default, IMAGE uses `px` (§14, R10). On a **line segment** a bare integer or
`#Nch` is not this constant — it means N average alphabet characters of the
segment's style (§5.4).

## 8. Column layout algorithm

1. Column width: explicit (`ch`/`px`/`auto`-measure of the widest row).
2. Number of columns = ⌊(page width − margins) / (col-width + gap)⌋, minimum 1.
3. Remaining rows are distributed as evenly as possible across that many columns
   (height-aware: the row count is reduced while any column's estimated height would
   overflow the available space).
4. If the first remaining row cannot fit the current page, a new page starts.
5. After a batch, the page advances by the tallest column; remaining rows continue on
   a new page.

## 9. Placeholders and tokens

Page tokens are replaced everywhere (header, content, footer) by **both** renderers:

| Token | Replacement |
|---|---|
| `<page>` | current page number |
| `<pages>` | total page count |
| `<now>` | current date/time, formatted per the value's style block (`[date]`/`[time]`/`[datetime]`; default datetime) |

`<now>` works both **inside a string** (`"Time: <now>" [time]`) and **as a pure value**
(`<now> [datetime]`); other tags pass through unchanged.

Only the angle-bracket forms are supported (the legacy `%PAGE%`/`%PAGES%` are gone).
The `%DATE%`/`%TIME%`/`%DATETIME%` string tokens are retained but optional — the
preferred way to show a date/time is a value + format style (see §5.3):
`(now) [date]`, `(now) [time]` (→ `hh:mm`), `(now) [datetime]`.

Example: `["Page <page> of <pages>" [b] (now) [time]]`

## 10. Headers and footers

- Each header/footer line's segments are placed **positionally**: 1st segment left,
  2nd centered, 3rd right; any further segments also left.
- Segments with no style block inherit a default **bold** style.
- Footer lines are laid out from the bottom margin upward.

## 11. Evaluation model

### 11.1 Parenthesized expressions

Write normal Red parens — `(now)`, `(total)`, `(widget-C)` — directly in the report.
`parse-report` **composes the template for you** (a deep compose) before parsing, so a
plain literal report needs no `compose/deep`. The one exception is **draw ops**: the
ops block of `DRAW`/`DRAW-BG` is skipped by that compose so its parens (`(as-pair
page-width 56)`, `(as-pair x y)`, …) are evaluated later by the renderer with the page
geometry and cursor in scope (§16.7).

Notes:

- Pre-composing with `compose/deep` yourself still works: with no parens left, the
  parser's compose is a no-op, so both styles coexist.
- Parens are evaluated at **parse time** in the calling context. Words the parens
  reference must be visible then — globals work; locals of an enclosing function do
  not (compose those yourself, or name the block; §16.7).
- A paren that yields a block is **spliced** as items (see the splicing rule below).
- `<now>`/`<page>`/`<pages>` string tokens are unrelated and still replaced by the
  renderers.

**Splicing rule (load-bearing for programmatically built reports):** `compose`
splices the *elements* of a block value produced by a paren — it never inserts the
block itself. Consequences, all verified:

- A builder returning ONE keyword item must be wrapped so the item stays whole:
  `[(builder)]` (the paren sits inside a block, so the block becomes the item).
- Appending a builder's item to a list needs `append/only`: `append result builder`
  would splice `COLUMN` and the items block as two separate elements.
- A section spliced by a top-level paren needs an extra wrapping block:
  `footer: compose/deep [[FOOTER […]]]` so `(footer)` inserts the section item,
  not its elements. (The old parser tolerated the un-wrapped forms via its
  top-level-word keyword path; the uniform grammar does not.)
- **A page is a block of items** — a single section passed where a page is expected
  (e.g. `show-popup` receives `[BODY […]]` and calls `parse-report` on it) must be
  wrapped: `[[BODY […]]]`. Builders for popups: `rpt: copy [[BODY []]]` and
  `append/only rpt/1/2 …` (or `compose/deep [[BODY [(rpt)]]]`).

### 11.2 Value resolution

`word!`/`get-word!` values are resolved via the enclosing context at parse time
(attempted `get`, falling back to the word itself). Word values therefore must be
visible in the parser's context; the demo reports define their data inside
`report-source` and use parens/compose so values are already literal by parse time.

### 11.3 Keyword normalization

A block is a keyword item iff its first element is a word (bare or quoted, any case)
matching one of `header body footer table image column pagebreak` (verified
empirically). The consequence for lines — a line whose first value is such a bare
word is parsed as a keyword item — is documented in §4.

### 11.4 Validation

`validate-report` returns `""` when the description is valid, else a message naming
the first problem. It is the single gate: `parse-report` assumes validated input and
is side-effect free (it no longer prints); anything invalid should be reported here
first. Checks include:

- unknown section keywords (`BODYX`), bare words between items, and bad paper
  directives (`a9`) — reported before parsing;
- a missing `BODY` (`BODY section is missing; a report needs a [BODY [...]] item`);
- unknown style words/lit-words in a style block — decorations/families/headings
  (`b i u s m h1-h3`), formats (`money s1000 date time datetime blank`), alignment
  (`< > ^`), `shadow`/`border`, `link-N`/`hint-N`, `!X` negations, widths
  (integers/floats, `#Npx`/`#Nch`) and colour words/tuples are allowed; anything
  else (`nosuchstyle`, `ok?`) is an error. Unknown negations (`!wibble`) are also
  caught, even though `merge-styles` would otherwise drop them;
- malformed `IMAGE`/`COLUMN`/`TABLE`, bad width tags, non-block table rows, sections
  nested inside sections, etc.

The demo reports all pass validation (verified).

## 12. Application interface

```red
parse-report page            ; -> object! [header content footer] (each: object [args lines])
validate-report page         ; -> "" | error message string
dump-report page-obj         ; debug print of the parsed structure

show-report report title                          ; parse a report block and show it (full/proportional view)
show-report/fit-width report title                ; start in fit-width mode
show-report/popup report title popup-fn           ; pass a click/hover callback
show-report/popup/fit-width report title popup-fn ; callback + fit-width
show-popup title content win-size                 ; modal styled popup (reuses the dialect)

report-view/make-font styles size                 ; set the global base font (View)
report-pdf/make-font styles size                  ; set the global base font (PDF)
report-view/make-font/line styles size factor     ; … and the line-spacing factor
report-pdf/make-font/line styles size factor
```

`make-font` sets the report's **global base font**: familiar style words
(`b i u s m h1-h3`, `link-N`, colours — see §5.2) plus a size in points, e.g.
`report-view/make-font [m] 8`. It applies to every value; per-line and per-value
styles merge on top, and `!X` drops a base style, so any value can still override
it locally (`[!m ss]` = sans where the base is mono). Headings scale with the base
size (`h1` = 2×, `h2` = 1.5×, `h3` = 1.17×; the 12 pt default gives 24/18/14 as
before). Line spacing is derived from **measured text**, not from font sizes: each
renderer supplies a metrics function `text-metrics text styles -> [width height
ascent]` (View: OS font line box; PDF: Base-14 metrics), and a line's height is the
largest such `height` among its values. Consecutive baselines are placed so the line
boxes touch, separated by `line-gap-px` (default 1): the baseline distance from one
line to the next is `descent(prev) + line-gap-px + ascent(next)`. The same metrics
size each value's background/frame box, so boxes hug the text and cannot overlap the
line above, and `h1`/`s-24`/plain text all lead correctly wherever they are used; a
wrapped string's visual lines each take part in the same rule. The only exception:
there is no gap before the first line of a page/block (nothing above it). Tune the
gap with `report-styles/line-gap-px`.

One `make-font` call configures the View **and** PDF renderers plus the shared
`report-styles` copy the parser reads, so calling it on either renderer
(`report-view/make-font …` or `report-pdf/make-font …`) is enough — that keeps
column widths and pagination consistent across both.

Two renderer-specific notes. The PDF uses the **Base-14** fonts only
(Times/Helvetica/Courier; no embedded fonts), and the View is set to matching
metric-compatible faces (`font-face-serif` `Times New Roman`, `font-face-sans`
`Helvetica`, `font-face-mono` `Courier`). The View renders ~1.3× wider per point
than the PDF and the three faces differ slightly, so the parity scale is set
**per family**: View `font-scale-serif` / `font-scale-sans` / `font-scale-mono`
(default `0.84`, base 12 → 10, rounded to whole points — GTK renders whole-point
sizes only) and PDF `font-scale-serif` / `font-scale-sans` / `font-scale-mono`
(default `1.13`, fractional is allowed). This lets each of the three fonts match
the PDF's separately; tune the six numbers for closest parity. Serif and sans-serif
glyph widths vary, so they cannot match exactly — **for the closest View/PDF match
use the mono family (`m`)**, whose fixed advance makes widths and line breaks line up.

`show-report` runs `validate-report` on the description first. It opens a window
only when the report is valid and then returns `""` (after the window is closed);
if the report is invalid it opens no window and returns the problem message
string. Callers (e.g. the sampler) can therefore fail fast and show the message.

`show-report` takes the report **block** and calls `parse-report` on it internally, so
callers no longer parse first. Paper size and orientation are **no longer parameters**
of `show-report`/the renderers — they come from the page's paper clause
(parsed `page-obj/paper` = `[size orientation]`).
Paper formats: `'a4` `'letter` `'legal` `'a3` `'a5` or an explicit `WxH` pair
(in points); the pair is width×height. `landscape` swaps the dimensions.
Default is a4 portrait (595×842 pt, 50 pt margins).

Example: `compose/deep [landscape letter [HEADER …] [BODY …] [FOOTER …]]`

---

## 13. Divergences from the original proposal (v1 → v2)

The draft `new-syntax-proposal.txt` and the implemented dialect differ in several
material ways. Each item is marked **adopted**, **rejected**, or **replaced**.

| # | Proposal (v1) | Implementation (v2) | Verdict |
|---|---|---|---|
| D1 | `report-source` is three bare positional blocks `[[header][content][footer]]` | Sections are keyword items: `[HEADER […]]` (optional) / `[BODY […]]` (required) / `[FOOTER […]]` (optional), any order | **Replaced** — bare blocks are ambiguous with line items; sections are ordinary keyword items in the uniform grammar |
| D11 | Keyword items mixed two shapes: top-level words (`'HEADER …`, `'TABLE …`) and blocks leading with a keyword (`['TABLE …]`) | **One uniform item shape**: `[known-word args… [items]?]` for sections, TABLE, COLUMN, IMAGE, PAGEBREAK; the two-block section-args form (`HEADER [args] [lines]`) is removed | **Adopted** — uniform, deterministic (first element decides), trivially parseable; trailing items block optional, `BODY` replaces `CONTENT` |
| D2 | Replace `%PAGE%`/`%PAGES%` with `<page>`/`<pages>` | Only `<page>`/`<pages>`; the `%`-forms were **removed** | **Adopted (regularized)** — one form, no legacy |
| D3 | Remove `'^`; missing alignment means center | `'^` kept; missing alignment means **left** | **Rejected** — proposal's default was reversed in practice |
| D4 | Integer width `-10` means right-align | Negative widths are inert; alignment via `'<`/`'>`/`'^` | **Rejected** — never implemented; superseded by explicit alignment |
| D5 | `separator` formatting style | Implemented as `'s1000` | **Replaced** — different name, same intent |
| D6 | `sans-serif`, `monospace` words | Short forms `'s`, `'m` | **Replaced** |
| D7 | `[IMAGE width %file]` | As proposed, plus `#px`/`#ch` unit tags, aspect-ratio scaling, page-height cap, columns support | **Adopted (extended)** |
| D8 | `[COLUMN (width) (gap) [items]]` | As proposed, plus `'auto` width, `ch` default units, gap default/min `1ch`, balanced height-aware layout, images inside, and column style args (`m s b u i h1-h3`, colors, `shadow`, `link-N`) inherited by every cell/contained IMAGE | **Adopted (extended)** |
| D9 | Header/footer lines use only the first three values | Positional layout L/C/R for segments 1–3, extra segments left | **Adopted (refined)** |
| D10 | (not in proposal) | `link-N`/`hint-N` interactive styles; `'date`/`'time`/`'datetime`; `h3`; `'blank` zero suppression; table-internal `PAGEBREAK` with header repeat; `validate-report`; paren safety net | **Added** — the proposal was incomplete on interactivity, formats, and table behavior |

Conclusion: the proposal's **item grammar is sound and was adopted**, but its
section syntax, alignment rules, and style naming were revised during
implementation; several implemented features (interactivity, table page-breaks,
units, validation) were never in the draft.

## 14. Known limitations (as of v2)

1. **No text wrapping** — long segments overflow the page width.
2. **PDF drops interactivity** — `link-N`/`hint-N` hotspots are View-only.
3. **Token handling** — `<page>`/`<pages>` are replaced by **both** renderers in header,
   content and footer (the old parity gap is closed); `<now>` uses `format-pair-value` (View+PDF).
4. **No nesting** — columns inside columns, tables inside columns, or multi-line cells
   are unsupported.
5. **No colspan** and no per-row vertical alignment.
6. **Custom named colors must be global** — a color word defined inside the report
   object is not found by `resolve-colors`.
7. **Section/TABLE style args now thread down** — `HEADER`/`BODY`/`FOOTER` and `TABLE` accept style words that inherit to every line/row/cell (per-value merge on top, `!X` cancels); only *non-style* section args (background, indent, column layout) are un-implemented.
8. **PDF images are JPEG-only** — PNG/BMP sources are converted lossily to JPEG.
9. **Headings and font scale are hard-coded per renderer** — heading sizes 24/18/14 pt; `font-size 12` pt and `line-height 18` pt in both; View scales headings by `font-scale 0.82`, PDF by `1.0`.

## 15. Recommendations and next steps

Prioritized roadmap — each item is independent and can be taken alone.

**P1 — Parity (mostly resolved)**
1. *(done)* `<page>`/`<pages>` now replace in **both** renderers (header, content, footer),
   closing the old PDF-content gap.
2. *(decided)* Links/hints stay **View-only** — PDF is for paper/printing, and a standalone viewer
   can't call back into the Red runtime; PDF link annotations would need a URL destination.

**P2 — Clean up the ambiguous style grammar**
3. **Alignment**: keep `'<`/`'>`/`'^` with explicit default `'<`; document it once
   in the spec. Consider rejecting negative width styles in `validate-report` so the
   inert `-10`/`-10.3` forms fail fast.
4. **Integer dual meaning** (pad width vs column width) is the biggest readability
   risk. Either rename the line-level concept or document it prominently — but keep
   column widths and pad widths visually distinct if possible.
5. **Naming**: pick canonical spellings — `'s1000` vs `separator`, `'s`/`'m` vs
   `sans-serif`/`monospace` — and add aliases in `report-styles` so both spellings
   parse. Canonical long names read better in reports.

**P3 — Make the syntax expressively complete**
6. **Text wrapping**: add word-wrap per line (with `col-w` constraint and wrapped
   height accounting in both renderers). This unlocks most real-world reports.
7. *(partial)* Section style args are implemented (they thread into content and
   inherit down). Remaining: non-style section args (per-section background, indent,
   column layout).
8. **Colors**: resolve color words against the report context as well as the global
   namespace (pass a context word, or resolve before `compose`).
9. **Nesting**: allow images already; add tables-in-columns and columns-in-columns
   next, since the emitter structure already generalizes.
10. **Units symmetry**: decide whether COLUMN bare numbers should default to `px`
    like IMAGE, or IMAGE to `ch` like COLUMN — or require explicit tags in both.

**P4 — Engineering hardening**
11. Run `validate-report` as a standard step in `show-report`/demo scripts (fail fast
    with the message instead of silent mis-rendering).
12. Add a regression harness: parse + validate + render each demo to PDF and to a
    View draw block, and diff outputs across renderers (catches parity regressions).
13. *(done)* Keyword handling is now the uniform `[known-word args… [items]?]` rule;
    case-insensitivity still relies on `find` word matching, which is accepted for now.
14. Make heading sizes, `font-scale`, `line-height-offset`, margins and gray shades
    configurable per report (currently context constants).
15. Consider `'PAGEBREAK` inside COLUMN rows (currently only IMAGE and lines) and
    document row-type support per container.

---

## 16. Advanced usage — raw draw

The core syntax above (text, styles, tables, columns, images, sections, tokens) is
the intended everyday surface. This section is the **escape hatch**: talking to the
page canvas directly. It is deliberately quarantined here because it adds a
coordinate system, a restricted command set, and renderer caveats that normal
reports never need.

Two layers exist, and they are complementary:

- **`[DRAW H [draw…]]`** — *inline foreground*. Placed in `BODY`, it paints at its
  position in the flow: over everything already emitted, under everything after it.
  Rendered as **native vector** by both the View and the PDF, so it works headless
  and never needs transparency.
- **`[DRAW-BG density? [draw…]]`** — *page background* (§3.1). Emitted first on
  **every** page, behind all content, and rasterized by the full draw engine, so it
  accepts the whole dialect (gradients, splines, effects, images). It is the right
  place for page chrome; it does not consume flow space.

Keep DRAW-BG for whole-page background art. Use DRAW for art that belongs to the
content flow (rules, badges, per-element frames, inline shapes).

### 16.1 Inline DRAW

```text
[DRAW H [draw…]]     ; H = integer points the item consumes in the flow (optional)
[DRAW [draw…]]       ; H omitted: measured from the ops (see 16.3), else invalid
```

Example — frame the paragraph just emitted, then a row of shapes with text under it
(see `samples/026-draw.red`):

```red
[BODY [
    ["This paragraph is framed by the DRAW that follows it." [b]]
    [DRAW 10 [
        pen 90.120.200  fill-pen off  line-width 1
        box (as-pair (prev-x - 5) (prev-y - 5))
            (as-pair (prev-x + prev-w + 5) (prev-y + prev-h + 5)) 6
    ]]
    ["Text continues below the frame."]
    [DRAW 44 [
        pen 0.0.160  fill-pen 235.242.255  line-width 2
        box (as-pair x y) (as-pair (x + 70) (y + 40)) 8
        circle (as-pair (x + 100) (y + 20)) 16
        line (as-pair (x + 130) y) (as-pair (x + 180) (y + 40))
        triangle (as-pair (x + 195) (y + 40)) (as-pair (x + 235) (y + 40)) (as-pair (x + 215) y)
    ]]
    ["Text continues underneath the shapes."]
]]
```

### 16.2 Coordinates and bound words

Coordinates are **page/draw space**: pixels from the page's top-left corner, y
growing downward — the same convention as DRAW-BG and Red's draw dialect. Words
bound inside the block:

| word | meaning |
|---|---|
| `x`,`y` | the running cursor: top-left where the next item would go |
| `w` | content width (page width minus left/right margins) |
| `h` | this draw's height `H` |
| `prev-x`,`prev-y`,`prev-w`,`prev-h` | the bounding box of the **previous item** (a whole wrapped paragraph, not one visual line), in draw space |
| `prev?` | true when a previous item box exists |
| `page-width`,`page-height` | page size in points |
| `margin-left/right/top/bottom` | content margins |

Because `prev-*` is the full box of the previous element, a frame is simply a `box`
drawn 4–5 px outside it (as above). A following DRAW and a following text line both
continue below the art: text after a DRAW steps one gap below it, so the art does
not overlap the text.

### 16.3 Height (`H`) and measuring

- `H` is the vertical space the item consumes; the next item's top is `H` below the
  cursor. `H = 0` is allowed (pure decoration that does not advance the flow).
- If `H` is omitted, the renderer measures the ops (the extent **below the cursor**,
  including stroke width). This only works with **literal** coordinates: a paren
  that references `x`/`h`/`prev-*` cannot be measured, so such blocks must give `H`.
- To clear a frame's overhang below its paragraph, use an `H` a few points larger
  than the overhang (e.g. `[DRAW 10 […]]` with a 5 px frame margin).

### 16.4 What is allowed

Both renderers reproduce one restricted subset; anything else is rejected by
`validate-report` so the View and the PDF never diverge:

| kind | allowed |
|---|---|
| state | `pen <tuple>` / `pen off`, `fill-pen <tuple>` / `fill-pen off`, `line-width`, `line-join` (miter/round/bevel), `line-cap` (flat/round/square), `anti-alias` |
| shapes | `box p1 p2` and `box p1 p2 radius` (rounded), `circle c r`, `ellipse c r`, `line p1 p2`, `triangle p1 p2 p3`, `polygon p1 p2 …` |

Colors are solid RGB tuples or Red color words (`coffee`, `gold`, …); the PDF resolves
named words the same way the View does, and `validate-report` **rejects an unknown
word** (e.g. `rebeccapurple`) instead of silently painting nothing. Not yet supported
(validation error): `text`, `image`, gradients, `spline`/`arc`/`curve`/`dot`,
`shape`/`draw` blocks, `clip`, `effect`, and any transform
(`translate`/`scale`/`rotate`/`skew`/`matrix`).
`polygon` takes its points as **separate arguments** (Red's draw dialect rejects a
block form).

DRAW is currently **BODY-only**; `HEADER`/`FOOTER` items would sit above/below the
content stream and need separate height accounting, so they are rejected for now.

### 16.5 Renderer notes

- Inline DRAW is emitted as native vector operators in the PDF, so it needs no GUI
  and no page-sized bitmap — unlike DRAW-BG, whose PDF path is rasterized and is
  skipped in headless runs.
- Because the PDF uses the Base-14 fonts while the View uses OS faces, `text` is not
  in the subset yet (glyph widths and measured heights would differ between the two).
- Transparent/filled art is not a problem: a foreground draw only paints its own
  ink, and alpha-0 colors are dropped, so nothing needs an alpha channel.

### 16.6 Ideas kept out of the current surface

- `text` and `image` inside DRAW, and inline-in-a-line DRAW (where `x` is the right
  edge of the previous value).

### 16.7 FRAME — a measured backdrop

`[FRAME R [draw-ops] [items]]` lays out its `items` (BODY text lines) to **measure**
them, then draws the `draw-ops` backdrop **behind** them. `R` is the padding around
the measured content box (integer, default 0).

This is the way to fill behind a wrapping paragraph: `DRAW` runs after its element
and can only paint *on top*, and the paragraph's height isn't known until it is laid
out.

```red
[FRAME 8 [
    pen 90.120.200  fill-pen 238.242.255  line-width 1
    box (as-pair x y) (as-pair x + w y + h) 6      ; rounded backdrop
] [
    ["A paragraph that wraps, framed from behind." [b]]
    ["A second line." [m]]
]]
```

Bound words inside the ops (page/draw space, top-down): `x y w h` = the **padded
frame box** (content + `R`); `cx cy cw ch` = the measured **content box**; `pad` = `R`;
plus `page-width`, `page-height`, `margin-*`. The ops are the same allowlisted draw
subset as DRAW (§16.4), rendered as native vector by both renderers.

Notes:

- FRAME is BODY-only; items are text lines (v1).
- FRAME acts like a block in the flow: preceding text is stepped past, and following
  content continues below the frame; `prev-*` for a following DRAW is the padded box.
- On overflow it restarts on a fresh page (View and PDF).

### 16.8 Parens, `compose/deep`, and DRAW

DRAW and DRAW-BG parens are evaluated at **render** time, with the page geometry in
scope (`page-width`, `page-height`, `margin-*`, and for DRAW the cursor/`prev-*`
words). Everything else is composed at **parse** time by `parse-report` (§11.1). The
parser knows about draw items, so it composes the report while leaving the ops blocks
alone — you just write the report literally:

```red
report: [ margin-20
    [DRAW-BG 3 [ pen off  fill-pen yellow  box 0x0 (as-pair page-width 56) ]]
    [HEADER [["Title" [h2] (now/date)]]]          ; (now/date) composed here
    [BODY   [["intro" [m]] [DRAW 30 [ box (as-pair x y) (as-pair x + 120 y + 24) ]] ["outro" [m]]]]
]
```

No `compose/deep` is needed. If you do pre-compose (older code), the parser's compose
is a no-op because no parens remain.

**Escape hatch — a named block.** If the ops must reference words that only exist in a
particular scope (e.g. locals of the function that builds the report), give the ops a
name; `compose/deep` never evaluates a word, and the parser resolves it:

```red
bg: [ pen off  fill-pen yellow  box 0x0 (as-pair page-width 56) ]
report: [ margin-20  [DRAW-BG 3 bg]  [BODY [["…"]]] ]
```

The same holds for `[DRAW H ops]`. Geometry stays in one place (the renderer) — nothing
about page size is duplicated at build time.

---

*This document supersedes `pdf-reports/new-syntax-proposal.txt`. The demo reports
(`Test-Report.red`, `Simple-Report.red`, `Long-Report.red`) are the living
examples of the v2 dialect and should be kept in sync with this spec.*
