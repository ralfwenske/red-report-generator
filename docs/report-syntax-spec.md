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
- **PDF renderer** (`report-pdf.red`) — a self-contained PDF generator (JPEG or lossless Flate image XObjects, embedded fonts, xref table).

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
- `word/value` — a qualified argument: `ss/10`, `margin/20`, `left/25`, `link/2`, `px/80`,
  `ch/20`, `gap-ch/4`, `border/2`. This is the **only** accepted spelling. Legacy `-N`
  forms (`ss-10`, `margin-20`, `px-80`) and `#Npx`/`#Nch` width tags are rejected by
  `validate-report` with a “use path notation” message.

## 3. Document structure

A report page description is a block: an optional *paper clause* (leading words/pair),
then the items. Three of those items are the *sections* — keyword items whose items
block becomes that section:

```text
page        := [ paper-clause? item … ]        ; paper clause, then items in any order
paper-clause := paper-size? orientation? margin? …
paper-size   := a4 | letter | legal | a3 | a5 | <WxH pair>   ; default a4
orientation  := landscape | portrait                          ; default portrait
margin       := top/N | bottom/N | left/N | right/N | margin/N   ; N in points, default 50

section-item := [HEADER [items] [items2]?]     ; optional; items2 = page 2 and later
              | [BODY   [items]]               ; required
              | [FOOTER [items] [items2]?]     ; optional; items2 = page 2 and later
              | [DRAW-BG density? [draw…]]     ; optional raw page background (§3.1, §16)

item         := … | [DRAW H? [draw…]]         ; BODY-only foreground art (Advanced, §16)
                 | [HEADER [items]]            ; BODY-only running override (see below)
                 | [FOOTER [items]]            ; BODY-only running override (see below)
```

- `BODY` is **required**; `HEADER` and `FOOTER` are optional and may appear in any order.
- `HEADER`/`FOOTER` may carry an **optional second block**: the first block is shown on
  page 1, the second on **page 2 and every later page** (`[]` means "none from page 2 on").
  Omit the second block to keep one header/footer on all pages. See §10.
- A `HEADER`/`FOOTER` item placed **inside `BODY`** is a *running override*: it takes
  effect **from the next page onward** (the page it appears on keeps its current
  header/footer) and stays in force for the rest of the report. `[]` clears it. See §10.
- The paper clause sets the page's size, orientation and margins for **both** renderers
  (default a4 portrait, 50 pt margins). Directives may be combined in any order
  (`[landscape a4 top/20 margin/15 …]`, `[600x800 portrait right/10 …]`); when repeated,
  the last size and last orientation win. For margins, `margin/N` sets a uniform default
  for all four sides and an individual `top/N`/`bottom/N`/`left/N`/`right/N` always overrides
  it — in **any order** (`[margin/25 top/10 …]` and `[top/10 margin/25 …]` give the same result).
  A **pair** (`600x800`) sets a custom
  width×height in points; margins are in points too (`top/20`, `right/10`, `margin/25`
  sets all four). Unknown leading words are invalid (reported by `validate-report`).
  All four margins measure from the page edge to the **top of the first line** (header
  if present, else the first body line), so the visual top gap equals `margin/N` just
  like the other sides.
- Words between a section keyword and its items block are section *args*. For
  `HEADER`/`BODY`/`FOOTER`/`TOC` these are **style words** that become the section's
  base style, inherited by every line/row/cell inside it (§4). Non-style section args
  (per-section background, indent, column layout) are not implemented (§13).

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
  template's parens for you, and the ops blocks of `DRAW-BG`/`DRAW`/`FRAME` (plus
  `AT` coordinates) are
  deliberately left uncomposed so their parens (`(as-pair page-width 56)`,
  `(as-pair x y)`) are evaluated at **render** time with the page/frame geometry in
  scope (§11.1, §16.7). Pre-composing the report would evaluate them too early.

`DRAW-BG` applies to all pages. To decorate a single page, draw oversized art on a
one-page report (raw draw is not clipped to the text margins).

## 4. Items

Every item is a block. Its first element decides the shape — a *known word*
makes it a keyword item, anything else makes it a *line*:

```text
item        := keyword-item | line-item

keyword-item := [ known-word args… [items]? ]   ; trailing items block optional
known-word   := HEADER | BODY | FOOTER | TABLE | COLUMN | IMAGE | PAGEBREAK | DRAW | FRAME | TOC | AT
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
  add; the deeper value wins on colors/alignment/format/width/family/size). Examples:
  `[BODY b [ … ]]`, `[TABLE b BOX ALT [rows]]`.
- **Negation `!X`.** Any style may carry `!b`/`!i`/`!u`/`!m`/`!s`/`!<`/`!>`/… which drops
  that attribute inherited from **all** higher levels. E.g. a row `[[!b] …]` inside a
  bold table renders not bold.
- **Argument matching.** Keyword args are matched by **type, not position**: each keyword
  accepts a fixed set of slots (width, source, modifier, colour, …) and they may appear in
  any order. A modifier carries its optional value as a `/N` suffix (`border/2`, `shadow/5`,
  `ss/8`, `gap-ch/4`), so a bare value is never ambiguous. **Widths are always spelled with
  a unit** — `px/N` or `ch/N` (never a bare integer); `auto` is allowed for `COLUMN` width.

### 4.1 Line items

`[ value style-block? value style-block? … ]`

- A *value* is any Red literal: `string!`, `number!`, `date!`, `tag!`, `issue!`, … (`none` → empty).
  To insert a computed value use a **paren**: `(now)`, `(total)`, `(backup-date)` — evaluated by
  the parser at build time (§11). A **bare word** is rejected by validation (it would just print
  its own name): write a string (`"text"`) or a paren (`(expr)`). `none` is the one exception and
  means an empty value.
- The *style-block* immediately following a value applies to that value only and is
  optional; it must not itself contain `string!` or `block!` values (that is how the
  parser tells a style block apart from a nested line).
- A **leading style-block** as the line's first element applies to *every* value on the
  line; a value's own style-block is **merged on top of it** — decorations like
  `b`/`i`/`u` add, and the value wins on colors, alignment, format, width, font
  family and font size. A sized word sets family and size together, so a value can
  override either or both: row `[s/10]` with value style `[ss/7 i]` gives sans 7
  italic. Example: `[[b red] "Total" "Δ" [i] 5123.88 [money]]` — bold red "Total",
  bold-italic red "Δ", and a bold-red money number. Works for table rows and column
  rows too.
- A single-segment line is rendered left-aligned; a multi-segment line flows
  segments left-to-right from the left margin. **BODY text lines wrap** at the
  content width (§5.7); header/footer, table and column rows do **not** wrap.
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

- *width* — column width: `px/N` or `ch/N`, or `auto` to auto-measure the widest row.
  Omitted → `auto`. A bare number is rejected (ambiguous); write `ch/N` or `px/N`.
- *gap* — space between columns, **attached to the word**: `gap-ch/N` (N average chars)
  or `gap-px/N` (N pixels). Default `1ch`, minimum `1ch`. Because it is named, it does not
  depend on position and `auto` is never needed to “skip” the width:
  `[COLUMN gap-ch/2 rows]` (auto width) and `[COLUMN px/280 gap-px/0 rows]`.
- *text (line) styles* — the remaining args apply to **line rows only**:
  `m`, `s`, `b`, `i`, `u`, `h1`/`h2`/`h3`, `link/N`/`hint/N` (make every cell
  interactive), color words (font colour for text), and negations (`!b` …). Useful to pin a font
  (e.g. `m`) so column widths are predictable. They never touch a contained `IMAGE`.
  Example: `[COLUMN ch/20 gap-ch/1 m rows]`.
- *image clause* — the word `image` followed by one style block styles every contained `IMAGE`
  (and only images): `[COLUMN … image [img-styles] [rows]]`. The image style block uses the IMAGE
  grammar from §4.4, including caption text styles — so a **family and/or size** applies to all
  the column's image captions, e.g. `image [shadow/3 silver s/8 link/1]`. It may carry a
  **default image width** (`px/N`/`ch/N`, e.g. `image [px/80 shadow/3 silver]`). Generics and
  the image clause may both be present (`[COLUMN b image [px/80 shadow/3 silver] rows]`): text
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

`[IMAGE width? box? colour? align? source]`  |  `[IMAGE width? box? colour? align? source [caption [styles]]]`

`box? := (shadow|border)(/N)?`   ; /N = inset in points

- **Arguments are matched by type, not position**: at most one width, one box modifier,
  one box colour, one alignment and one source, in any order. `[IMAGE 120 shadow/3 silver %f]` and
  `[IMAGE shadow/3 silver 120 %f]` are equivalent.
- *align?* — an optional placement token `<` (left, default), `^` (centre) or `>`
  (right) that positions the whole image block (box **and** image, plus its caption)
  horizontally within the content width (`page-width - margin-left - margin-right`);
  inside a `COLUMN` it aligns within the column cell. `[IMAGE ^ px/400 %f]` centres a
  400 px image. The alignment shifts the image, it does not change its width.
- *width* — `px/N` or `ch/N` (a bare number is rejected as ambiguous). When omitted the
  image is scaled to its **intrinsic proportions, contained to the space still free on the
  current page** (so it fits under preceding text instead of forcing a page break); put it
  first in the body for a full-page image. Inside a `COLUMN` a width-less image is contained
  to the column width (see §4.3).
  For backward compatibility a width at the start of the caption style block (`px/N`/`ch/N`)
  is also honoured as a fallback when no width argument is given.
- *box?* — `shadow` (drop shadow; base and image the same size, offset down-right) or
  `border` (frame box). The optional inset is **attached to the word** as `/N`
  (`border/2`, `shadow/5`) — like `ss/8` — default 5% of the image width. No bare integer
  follows the box word, so an integer argument is always the image width.
- optional *colour* — the box colour (default `silver`).
- *source* — a `file!` or `string!` path, **or an `image!`** value (e.g. a generated
  image supplied through a paren: `(make image! reduce [200x100 0.128.255])`). An
  in-memory image needs no file on disk and is embedded/rendered like a file source.
- The optional trailing block is the image's **caption line** — exactly one value + a style block.
- *caption* — a `string!`, drawn **centered one line below** the image. When the caption line is
  omitted, the caption defaults to the **file's name without extension** (`Empress.jpg` →
  `Empress`) for file sources; an `image!` source has no name, so it gets **no caption**
  unless one is supplied. A `""` value gives **no caption**.
- *styles* (the caption's style block) — **pure text styles**: `b i u s`/`ss`/`m`,
  `h1-h3`/`f1-f4`, any `/N` size (`s/8`, `m/10`), `link/N`, `hint/N`, `!X`, and the
  trailing 1–3 **colours** (font, background, frame) — exactly as on a line. The caption
  keeps the normal text size unless its style block sets one. `link/N`/`hint/N` make the
  **whole image area** an interactive hotspot (the caption is the popup text, `N` the id);
  `link/N` implies a solid underline, `hint/N` a dotted one (View-only).
  (Legacy: `shadow`/`border` at the start of the caption style block is still parsed for old
  reports, but new reports put the box clause after `IMAGE`.)
- Examples:
  - `[IMAGE %Empress.jpg]` — intrinsic width contained to the page; caption `Empress`.
  - `[IMAGE 120 shadow/3 red %Empress.jpg ["Empress" [link/1]]]` — 120 px, red shadow, linked.
  - `[IMAGE px/120 border/3 silver %Empress.jpg ["Empress"]]` — explicit px unit, silver frame.
  - `[IMAGE %Empress.jpg ["Empress" [b red blue]]]` — intrinsic width, no box; bold caption, red on blue.
  - `[IMAGE 120 border/2 silver %Magician.jpg [""]]` — framed, no caption.
  - `[IMAGE ^ px/400 %Empress.jpg]` — centred 400 px image; `[IMAGE > px/400 %Empress.jpg]` right-aligns it.
  - `[COLUMN px/120 ch/4 image [shadow/3 silver] [ [IMAGE %a.jpg] [IMAGE %b.jpg [""]] ]]` — a column
    of images: the column's `image [styles]` clause uses the style-block grammar (box allowed) and
    applies to every contained image; uniform row height, captions default to the file name.
- Height derives from the image's aspect ratio; the base extends the occupied height.
  Works in both renderers, including inside a `COLUMN`.
- PDF output embeds raster images as XObjects: `.jpg/.jpeg` sources become **JPEG**
  (`/DCTDecode`, lossy); PNG/BMP sources and in-memory `image!` values are stored
  **losslessly** as zlib `/FlateDecode` RGB (so screenshots and diagrams stay
  sharp); `.gif/.webp` use JPEG. Transparency is carried as a grayscale `/SMask`
  XObject, so an RGBA source composites over any backdrop; a fully opaque image
  gets none. A lossless image needs a width divisible by 4 (Red's image accessors
  shear rows when the byte stride needs 4-byte padding); other widths still embed
  correctly, but as JPEG. (The View renderer loads images natively; links/hints are
  View-only.)

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
width box** (`w.d` float, integer `N`, `ch/N`, `px/N`) defaults to **right**, so numbers
and their decimal points line up. An explicit `<`/`^`/`>` always wins. (The original
proposal suggested "center if no alignment given" — *not* adopted; `'^` was kept. See §13.)

### 5.2 Decoration

| Style | Meaning |
|---|---|
| `b` | bold (implied by `h1`–`h3` and `f1`–`f3`) |
| `i` | italic |
| `u` | underline |
| `!u` | negate underline — suppresses `u`, and the automatic underline implied by `link/N`/`hint/N` |
| `s` | serif font (the default) |
| `ss` | sans-serif font |
| `m` | monospace font (widths are `length × cell advance`, independent of font ligatures, so the View and PDF agree) |
| `f1` / `f2` / `f3` | style-only heading sizes 24 / 18 / 14 pt (2× / 1.5× / 1.17× of the base), bold |
| `f4` | style-only reset to the base size, not bold (useful to end a heading within a line) |
| `h1` / `h2` / `h3` | like `f1`/`f2`/`f3` **and** they mark the heading for the table of contents (§9.1) |
| `word/N` | any style word may carry a size suffix (points), e.g. `i/8` (italic 8), `m/10` (mono 10), `ss/12` (sans 12), `h2/20`; it sets that value's font size, or the whole line when used in the line's leading style block |

### 5.3 Value formatting

| Style | Meaning |
|---|---|
| `money` | `$` + thousands separators + 2 decimals; negatives as `-$n.nn` |
| `s1000` | thousands separators, no decimals |
| `10.3` (float) | number format: `3` decimals, and on a line segment the width `10` is a box of 10 average characters (see §5.4); a numeric value with a box defaults right-aligned |
| `date` / `time` / `datetime` | format a `date!` value as date / time (`hh:mm`) / date+time. Use `(now) [date]` / `(now) [time]` / `(now) [datetime]` |
| `px/N` | literal N-pixel per-value width (see §5.4) |
| `ch/N` | N average characters of the segment's style (see §5.4) |
| `blank` | in table cells: suppress `0` numeric values |

A bare integer is **not** a width — write `px/N` or `ch/N` (validation rejects it as
ambiguous).

Note on the float form: a negative width (e.g. `-10.3`) is parsed but has **no
effect** — the proposal's "negative width = right-align" rule was never implemented;
use `'>` instead (§13).

### 5.4 Widths on a line segment

A width on a line segment defines a **box** for that value; the value is laid out in
the box honouring its alignment, and the next segment starts at the box's right edge.

- `px/N` — a literal N-pixel box.
- `ch/N` — a box of `N` **average characters of the segment's style/font**. The average
  is measured once over the alphabet `a`–`z` `A`–`Z` in the resolved style (font family,
  size, weight, italic), so it depends only on the style, **not** on the value's own text.
  Two segments sharing a style therefore get the same box for the same `N`, which makes a
  column of following values line up. A bare integer is **not** accepted here — write
  `ch/N` or `px/N`.
- float `w.d` on a number — a character box of width `w`, with `d` decimals in the
  formatted number (this is a *number format*, not a plain width).
- If the text is wider than the box, the text wins (no truncation) and the cursor
  advances past it.

A **numeric** value with any of these boxes defaults to **right** alignment in its box
(so decimal points line up); other values default to left, and an explicit `<`/`^`/`>`
overrides in every case.

| Context | Width means |
|---|---|
| line segment (content/header/footer), `ch/N` | N average alphabet characters of the segment's style |
| line segment, float `w.d` on a number | character box of size `w`, `d` decimals |
| line segment, `px/N` | N literal pixels |
| table header row cell | column width: `ch/N` (or `px/N`) |

Widths are always unit-qualified, so there is no integer-vs-column dual meaning.

### 5.5 Colors

Colors may appear **anywhere** in a style block (interleaved with other styles, not only
last) and may be given as:

- a tuple: `255.165.0` (RGB);
- a word resolving (in the **global** namespace) to a tuple — Red's predefined
  color words (`red`, `blue`, `green`, `yellow`, `black`, `white`, `gray`,
  `purple`, `coffee`, …) or any user-defined global tuple word.

Their **relative order** defines the role (1st = font color, 2nd = background,
3rd = frame/border), regardless of where they sit among the other styles:

```red
["text" [b 255.0.0 0.128.0 10.10.10]]   ; bold red text, dark-green bg, gray frame
["text" [red b 0.128.0 10.10.10]]       ; colours first, decoration after — same result
["text" [h1 red]]                       ; heading, red font
```

#### Predefined colour shades

The library also ships a **shaded palette** as plain global tuple words, so each
family is available at ten tints: `<family>0` (**lightest**) … `<family>9`
(**darkest**):

`gray red pink grape violet indigo blue cyan teal green lime yellow orange`

```red
["soft" [black gray1]]        ; gray1 = lightest gray
["warn" [red8]]               ; red8 = a dark red
fill-pen red3                 ; a mid red tint (DRAW / DRAW-BG)
```

These words are defined **globally** by `libs/report-styles.red` when the library
loads (table `report-styles/shade-tuples` is the source of truth); no `do load` is
needed. `assets/color-tuples.red` — generated by `assets/utils/make-colors.red`
from `assets/utils/colors.json` — mirrors the same table for use **outside** the
generator (e.g. `do load %assets/color-tuples.red` in a plain Red script). The base
Red colour words (`red`, `gray`, …) are untouched; the shade words do not shadow them.

### 5.6 Interactive styles (View renderer only)

| Style | Meaning |
|---|---|
| `link/N` | clickable hotspot; on click calls the popup handler with `'link N text` |
| `hint/N` | hover hint; after the hint delay calls the handler with `'hint N text` |

A `link/N` style implies a **solid** underline, a `hint/N` style a **dotted** one,
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
| `ch/N` (or `px/N`) | column width (default `12ch`) — a bare integer is rejected |
| `money` / `s1000` / float `10.2` | default number format for the column |
| `b` | bold column values |
| `blank` | suppress `0` values in this column |

Data rows may override per-cell: the cell's own style block is merged with the column
defaults (column `b` is inherited; the first tuple is used as the cell's font color;
`blank`/`s1000`/`money` are honored from either source). Alignment/format from
the column spec win unless overridden by `<`/`>`/`^` in the cell.

## 7. Units

Widths are **always explicit** — a bare integer is rejected as ambiguous.

| Tag | Meaning |
|---|---|
| `px/N` | `N` pixels |
| `ch/N` | `N` average characters (`1ch ≈ 0.583 × font-size`; default 12 pt ⇒ 7 px) |
| `gap-ch/N` | `N` average characters — COLUMN gap |
| `gap-px/N` | `N` pixels — COLUMN gap |
| `w.d` (float) | number format: box of `w` chars, `d` decimals (not a plain width) |

Applies to `COLUMN` width, `IMAGE` width, table header-row cell widths and line-segment
width boxes. On a line segment, `ch/N`/`N` means N average characters of the segment's
style (§5.4); `px/N` is literal. There is no default-unit asymmetry any more.

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

**Escaping.** To show a token literally, prefix the `<` with a backslash:
`["Use \<page> for the number"]` renders `Use <page> for the number` (no replacement).
`\<` protects the `<` from both `<now>` expansion and the `<page>`/`<pages>` pass, and
the backslash itself is removed at render. This works in BODY text, COLUMN rows,
HEADER and FOOTER. (Backslash is a literal character in Red strings, so no extra
quoting is needed.)

### 9.1 Table of contents

`h1`/`h2`/`h3` render like the style-only `f1`/`f2`/`f3` **and** register a heading.
A `[TOC [pattern lines]]` item in `BODY` is expanded — once every page is known —
into the collected headings, **in document order** (i.e. page order). The pattern
line whose placeholder names a level supplies that level's format and indentation,
so **a heading level is listed exactly when a pattern line for it exists** (there is
no depth argument):

```
[TOC [
    ["<h1>" [f2 px/300] "<t-page>" [f2]]
    ["  <h2>" [f2 px/300] "<t-page>" [f2]]
    ["    <h3>" [s/12 px/300] "<t-page>" [s/12]]
]]
```

- Each `<h1>`/`<h2>`/`<h3>` pattern line formats headings of that level; entries are
  emitted in the order the headings occur, so hierarchy shows through the indentation
  (leading spaces) each pattern supplies. A level with no pattern line is omitted.
- `<t-page>` becomes that heading's page number; `<hN>` becomes its text (the first
  value of the heading line).
- Put `link/toc` in a pattern line's style block to make each entry **clickable**:
  it expands to a per-entry link id (`toc-N`) whose target is the heading's page, and
  clicking it in the viewer jumps to that page (View only — PDF drops links). Like any
  link it implies a solid underline; add `!u` to suppress that.
- A pattern line with no placeholder is emitted literally, first (a caption such as
  `["CONTENTS" [f2]]`).
- Pattern lines are ordinary value/style lines, so `px/N` widths push the page number
  into a column. Prefer `px/N` on the text segment so the filled-in number cannot
  re-wrap the line.
- The entry count comes from the content, so the TOC's height is fixed before page
  numbers are filled — pagination is stable. `TOC` is `BODY`-only.

## 10. Headers and footers

- `HEADER`/`FOOTER` blocks contain **text lines only** (`TABLE`/`COLUMN`/`IMAGE`/`DRAW`
  are not rendered there and are rejected by validation; see §14.10).
- Each header/footer line's segments are placed **positionally**: 1st segment left,
  2nd centered, 3rd right; any further segments also left.
- Segments with no style block inherit a default **bold** style.
- Footer lines are laid out from the bottom margin upward.

### 10.1 Page-2 header/footer block

`HEADER`/`FOOTER` accept an optional **second block**. When present, block 1 is used on
page 1 and block 2 on page 2 and every later page; an empty second block (`[]`) means
"no header/footer from page 2 on". When the second block is omitted, the first block is
used on all pages (the previous behaviour).

```red
[FOOTER [
    ["Footer" [h3] "" "Page <page> of <pages>"]   ; page 1
][
    ["<page> of <pages>" "" "confidential"]       ; page 2 onward
]]
```

The reserved header space is the tallest variant's first line and the reserved footer
space is the tallest footer, so page capacity (and `<pages>`) stays stable across pages.

### 10.2 Running overrides inside BODY

A `HEADER`/`FOOTER` item placed **inside `BODY`** is a running override: it takes effect
**from the next page onward** — the page it is written on keeps its current header/footer
— and stays in force to the end of the report (or until the next override). `[]` clears
the header/footer from the next page on.

```red
[BODY [
    ["page 2 content here"]
    [PAGEBREAK]
    [HEADER [["Section 2" [h2]]]]         ; shown from page 3 on
    [FOOTER [[ "Page <page> of <pages>" ]]]
    ["page 3 content here"]
]]
```

Overrides may be written anywhere in the body; the effective header/footer for a page is
the section default for that page (page 1 vs page 2+, §10.1) with the most recent override
seen before the page began. An override's height contributes to the reserved band, so
switching to a taller header/footer never clips the top or bottom margin.


## 11. Evaluation model

### 11.1 Parenthesized expressions

Write normal Red parens — `(now)`, `(total)`, `(widget-C)` — directly in the report.
`parse-report` **composes the template for you** (a deep compose) before parsing, so a
plain literal report needs no `compose/deep`. The one exception is **draw ops**: the
ops block of `DRAW`/`DRAW-BG` is skipped by that compose so its parens (`(as-pair
page-width 56)`, `(as-pair x y)`, …) are evaluated later by the renderer with the page
geometry and cursor in scope (§16.7).

Notes:

- Do **not** `compose/deep` the whole report yourself. It would also evaluate the
  draw-ops parens of `DRAW`/`DRAW-BG`/`FRAME` (`(as-pair x y)`, `(as-pair page-width
  margin-top)`) in the caller's context, where `x`/`y`/`margin-*`/`page-*` may not
  exist yet — that is the `x has no value` error. Pass the literal report; the parser
  composes the non-ops parts and defers the ops. If you must pre-compose, compose only
  the parts that contain no draw ops.
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
matching one of `header body footer draw-bg table column image pagebreak draw frame toc`
(verified empirically). The consequence for lines — a line whose first value is such a
bare word is parsed as a keyword item — is documented in §4.

### 11.4 Validation

`validate-report` returns `""` when the description is valid, else a message naming
the first problem. It is the single gate: `parse-report` assumes validated input and
is side-effect free (it no longer prints); anything invalid should be reported here
first. Checks include:

- unknown section keywords (`BODYX`), bare words between items, and bad paper
  directives (`a9`) — reported before parsing;
- **legacy notation** — `ss-10`, `margin-20`, `px-80`, `#46px`/`#70px` are rejected with
  a “use path notation” message (`ss/10`, `margin/20`, `px/80`, `px/46`);
- a missing `BODY` (`BODY section is missing; a report needs a [BODY [...]] item`);
- unknown style words/lit-words in a style block — decorations/families/headings
  (`b i u s m h1-h3`), formats (`money s1000 date time datetime blank`), alignment
  (`< > ^`), `shadow`/`border`, `link/N`/`hint/N`, `!X` negations, widths
  (`px/N`/`ch/N` and floats as number formats) and colour words/tuples are allowed;
  anything else (`nosuchstyle`, `ok?`) is an error. A **bare integer** in a style block
  is reported as an ambiguous width (use `px/N` or `ch/N`). Unknown negations
  (`!wibble`) are also caught, even though `merge-styles` would otherwise drop them;
- malformed `IMAGE`/`COLUMN`/`TABLE`, bad width tags, non-block table rows, sections
  nested inside sections, etc.

The demo reports all pass validation (verified).

### 11.5 Item argument schema

Every keyword item is described once, declaratively, in `report-parser`'s
`item-schema`:

```red
; keyword -> [arg-kinds  child-keywords]
header    [[style]              []]
footer    [[style]              []]
body      [[style]              [table image column pagebreak draw frame header footer toc]]
table     [[modifier style]     []]
column    [[width modifier style] [image pagebreak]]
image     [[width source]       []]
draw      [[integer]            []]
draw-bg   [[integer]            []]
frame     [[integer]            []]
pagebreak [[integer]            []]
toc       [[integer style]      []]
```

`collect-args` classifies a keyword's arguments into typed buckets (`styles`,
`widths`, `files`, `modifiers`, `integers`) via `arg-kind`. Arguments are matched by
**type, not position**. `IMAGE` and the `COLUMN` gap use dedicated parsers:
`IMAGE` accepts `width?` (`px/N`/`ch/N`), one box modifier (`shadow|border` with `/N`),
one box colour, one alignment (`<|^|>`) and one source (file/string/image), in any order; `COLUMN` accepts one
width (`px/N`/`ch/N`/`auto`), one gap (`gap-ch/N`/`gap-px/N`) and styles, in any order.

Args are matched against their kind: styles include the family/size/decoration/
format vocabulary and colours; widths are **always** `px/N`/`ch/N` (or `auto` for a
COLUMN) — a bare number is rejected as ambiguous; `source` is a file/string path or an
`image!` (IMAGE); modifiers are `BOX`/`ALT` (TABLE) and `gap-ch/N`/`gap-px/N` (COLUMN);
integers are the optional DRAW/FRAME/DRAW-BG/PAGEBREAK numbers. Anything else is
reported, e.g. `unexpected argument 7 for TABLE` or `unknown style word 'nope'`.

## 12. Application interface

```red
parse-report page            ; -> object! [header content footer]
                             ;    header/footer: object [args lines lines2 extra]
                             ;    lines2 = page-2+ block (none when absent)
validate-report page         ; -> "" | error message string
dump-report page-obj         ; debug print of the parsed structure

show-report report title                          ; parse a report block and show it (full/proportional view)
                                                  ; title may contain %page-size% (see below)
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
(`b i u s m f1-f4 h1-h3`, `link/N`, colours — see §5.2) plus a size in points, e.g.
`report-view/make-font [m] 8`. It applies to every value; per-line and per-value
styles merge on top, and `!X` drops a base style, so any value can still override
it locally (`[!m ss]` = sans where the base is mono). Heading levels scale with the base
size (`f1`/`h1` = 2×, `f2`/`h2` = 1.5×, `f3`/`h3` = 1.17×, `f4` = 1×; the 12 pt
default gives 24/18/14 as before), and `h1`/`h2`/`h3` additionally register as table-of-contents
headings (§9.1). Line spacing is derived from **measured text**, not from font sizes: each
renderer supplies a metrics function `text-metrics text styles -> [width height
ascent]` (View: OS font line box; PDF: Base-14 metrics), and a line's height is the
largest such `height` among its values. `height` is the full line box and `ascent`
is the font's true ascender (the box split by `report-styles/box-ascent-frac`), so
values set in different families share one baseline instead of each sitting its own
descent above the line. Consecutive baselines are placed so the line
boxes touch, separated by `line-gap-px` (default 1): the baseline distance from one
line to the next is `descent(prev) + line-gap-px + ascent(next)`. The same metrics
size each value's background/frame box, so boxes hug the text and cannot overlap the
line above, and `h1`/`s/24`/plain text all lead correctly wherever they are used; a
wrapped string's visual lines each take part in the same rule. The only exception:
there is no gap before the first line of a page/block (nothing above it). Tune the
gap with `report-styles/line-gap-px`.

One `make-font` call configures the View **and** PDF renderers plus the shared
`report-styles` copy the parser reads, so calling it on either renderer
(`report-view/make-font …` or `report-pdf/make-font …`) is enough — that keeps
column widths and pagination consistent across both.

Two renderer-specific notes. The PDF uses the **Base-14** fonts only
(Times/Helvetica/Courier; no embedded fonts). The View uses metric-compatible
faces selected per platform (`system/platform`):

| Platform | serif | sans | mono |
|---|---|---|---|
| Windows | Times New Roman | Arial | Courier New |
| Linux / macOS / other | Times New Roman | Helvetica | Courier |

The View measures OS-font pixels while the PDF uses points/AFM, so the PDF
renderer carries **per-platform** multipliers:

- `report-pdf/font-scale-*` — glyph advances (width, wrapping, column measurement)
- `report-pdf/line-scale-*` — line-box height
- `report-pdf/font-scale-heading-*` / `line-scale-heading-*` — h1/h2/h3 (and f1–f3)
- `report-styles/ascent-frac-*` — baseline split, shared by both renderers
- `report-pdf/glyph-scale` — PDF glyph height. The View renders at 96 dpi
  (12 pt → 16 px), so PDF text is drawn at `nominal * 1.3333` (`Tf`) with
  `Tz = font-scale / 1.3333`, which keeps the measured advances/wrapping but
  matches the View's glyph height. Do not set `Tf` to the advance size: the
  PDF glyphs then come out about 5% shorter than the View's.

On Windows and macOS, both renderers share one vertical grid: the View takes
its line-box height from `report-pdf/font-line-scale-for` (per family and size)
while widths still come from the OS font, so small-size rounding (e.g. `m/9`)
cannot accumulate into different page breaks. Linux keeps the View's measured
box. The View's own `font-scale-*` stay at `1` (Red View sizes are whole
points). Current values (2026-10-26, Red 0.6.6):

On Windows, the View draw shaper advances mixed text about 3.5% wider than
`size-text` reports. `report-styles/view-width-factor` (Windows `1.035`,
Linux/macOS `1.0`) is applied to the View's line/column measurement and to the
PDF advances, so wrapping lands on the edge that is actually drawn. The Windows
rows below already include that factor. Full-view pages are rasterized at 100%
for layout parity; fit-width pages may supersample up to 3x for image sharpness,
but 3x text hinting can add another ~3.5% advance.

| Platform | body font s/se/m | body line s/se/m | ascent s/se/m | heading font s/se/m | heading line s/se/m |
|---|---|---|---|---|---|
| Windows | 1.3110 / 1.3419 / 1.3889 | 1.56 / 1.50 / 1.50 | 0.815 / 0.84 / 0.74 | 1.3559 / 1.3621 / 1.308 | 1.50 / 1.55 / 1.50 |
| Linux | 1.32 / 1.38 / 1.40 | 1.56 / 1.40 / 1.40 | 0.79 / 0.715 / 0.60 | same as body | same as body |
| macOS | 1.2496 / 1.2498 / 1.25 | 1.4167 / 1.61 / 1.61 | 0.81 / 0.62 / 0.62 | 1.2840 / 1.2840 / 1.2840 | 1.47 / 1.60 / 1.60 |

Windows and macOS values are measured with `red-view tests/metrics-probe.red`
(it writes `tests/metrics-probe.txt`); re-run it after changing faces or the Red
build. Serif and sans glyph widths still vary slightly, so they cannot match
exactly — **for the closest View/PDF match use the mono family (`m`)**, whose
fixed advance makes widths and line breaks line up.

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

### 12.1 Window title and `%page-size%`

The `title` argument is used for the viewer window title and for the saved-PDF file
name. Page size is **not** appended automatically. To show it in the window title,
put the placeholder `%page-size%` in the title string:

```red
show-report/fit-width report "005 — Minimal %page-size%"
```

- **Window title:** `%page-size%` is replaced by the page size in points,
  `width x height` (e.g. `595 x 842`).
- **Saved PDF file name:** the placeholder is removed, so files keep a clean name
  (`005 — Minimal.pdf`).
- A title without `%page-size%` shows no page size (the previous automatic
  `" (W x H)"` suffix was removed).

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
| D8 | `[COLUMN (width) (gap) [items]]` | As proposed, but arguments are type-matched: width `px/N`/`ch/N`/`auto`, gap `gap-ch/N`/`gap-px/N`, plus balanced height-aware layout, images inside, and column style args (`m s b u i h1-h3`, colors, `shadow`, `link/N`) inherited by every cell/contained IMAGE | **Adopted (extended)** |
| D9 | Header/footer lines use only the first three values | Positional layout L/C/R for segments 1–3, extra segments left | **Adopted (refined)** |
| D10 | (not in proposal) | `link/N`/`hint/N` interactive styles; `'date`/`'time`/`'datetime`; `h3`; `'blank` zero suppression; table-internal `PAGEBREAK` with header repeat; `validate-report`; paren safety net | **Added** — the proposal was incomplete on interactivity, formats, and table behavior |

Conclusion: the proposal's **item grammar is sound and was adopted**, but its
section syntax, alignment rules, and style naming were revised during
implementation; several implemented features (interactivity, table page-breaks,
units, validation) were never in the draft.

## 14. Known limitations (as of v2)

1. **No wrapping in header/footer, tables or columns** — long segments overflow their
   cell/page width. **BODY text lines do wrap** at the content width (§5.7).
2. **PDF drops interactivity** — `link/N`/`hint/N` hotspots are View-only.
3. **Token handling** — `<page>`/`<pages>` are replaced by **both** renderers in header,
   content and footer (the old parity gap is closed); `<now>` uses `format-pair-value` (View+PDF).
4. **No nesting** — columns inside columns, tables inside columns, or multi-line cells
   are unsupported.
5. **No colspan** and no per-row vertical alignment.
6. **Custom named colors must be global** — a color word defined inside the report
   object is not found by `resolve-colors`.
7. **Section/TABLE style args now thread down** — `HEADER`/`BODY`/`FOOTER` and `TABLE` accept style words that inherit to every line/row/cell (per-value merge on top, `!X` cancels); only *non-style* section args (background, indent, column layout) are un-implemented.
8. **PDF images** — `.jpg/.jpeg` stays JPEG (lossy); PNG/BMP and `image!` are lossless Flate RGB; a source with transparency also carries a grayscale `/SMask` so it composites over the backdrop.
9. **Font parity is measured per platform** — heading sizes are 24/18/14 pt, base
   is 12 pt. Windows and macOS body text is calibrated to within ~1 px; line
   heights and baselines match exactly because both renderers share the per-size
   vertical grid. Serif/sans heading widths can still differ by a few percent
   because the OS face and the Base-14 face are not identical. Windows and macOS
   values are measured with `tests/metrics-probe.red`; Linux retains the original
   calibration.
10. **`HEADER`/`FOOTER` accept text lines only** — `TABLE`/`COLUMN`/`IMAGE`/`DRAW` are
    not rendered there and are rejected by validation. Use `DRAW-BG` for a page-wide
    logo or `DRAW` in `BODY`. (Allowing `DRAW`/`IMAGE` in a running header/footer is a
    planned extension — §16.6.)

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
10. **Units** — done: every width is explicit (`px/N` or `ch/N`); COLUMN gaps are
    `gap-ch/N`/`gap-px/N`; bare integers are rejected as ambiguous.

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

A DRAW starts at the cursor, and the cursor sits just below the previous value-line
(its descent + the 1 px line gap) — so a rule drawn at `y` lands directly under the
preceding line. (Other blocks, e.g. TABLE/IMAGE, step past by half the line box.)
`prev-*` is the full box of the previous element, so a frame around a wrapped
paragraph is simply a `box` drawn 4–5 px outside it. Following text continues below
the art, one line gap under the consumed height.

### 16.3 Height (`H`) and measuring

- `H` is the vertical space the item consumes; the next item's top is `H` below the
  cursor. `H = 0` is allowed (pure decoration that does not advance the flow).
- If `H` is omitted, the renderer measures the ops: the ink extent **below the
  cursor** (including stroke half-width) **plus `draw-bottom-gap` (3 px)**. This only
  works with **literal** coordinates: a paren that references `x`/`h`/`prev-*` cannot
  be measured, so such blocks must give `H`.
- To move the *art* rather than the following line, offset it in the ops, e.g.
  `line (as-pair x (y + 4)) …`; to leave more/less room below it, set `H`.
- To clear a frame's overhang below its paragraph, use an `H` a few points larger
  than the overhang (e.g. `[DRAW 10 […]]` with a 5 px frame margin).

### 16.4 What is allowed

Both renderers reproduce one restricted subset; anything else is rejected by
`validate-report` so the View and the PDF never diverge:

| kind | allowed |
|---|---|
| state | `pen <tuple>` / `pen off`, `fill-pen <tuple>` / `fill-pen off`, `line-width`, `line-join` (miter/round/bevel), `line-cap` (flat/round/square), `anti-alias` |
| shapes | `box p1 p2` and `box p1 p2 radius` (rounded), `circle c r`, `ellipse c r`, `line p1 p2`, `triangle p1 p2 p3`, `polygon p1 p2 …` |
| image | `image <src> <top-left> <bottom-right>` or `image <src> <top-left>` (natural size). `<src>` is an `image!`, a `file!` (auto-loaded), or a word bound to either — so `image %logo.png 10x20 110x70`, `image (load %logo.png) 10x20`, and `img: load %logo.png` + `image img 10x20` all work. **Put a position outside the paren** — `image (load %logo.png) 10x20`, not `image (load %logo.png 10x20)` (a paren returns its last expression, i.e. the pair). Handy for logos/watermarks in `DRAW`, `DRAW-BG` and `FRAME` |

Colors are solid RGB tuples or Red color words (`coffee`, `gold`, …); the PDF resolves
named words the same way the View does, and `validate-report` **rejects an unknown
word** (e.g. `rebeccapurple`) instead of silently painting nothing. The `image` command
embeds as an image XObject in the PDF (JPEG for `.jpg` sources, lossless Flate otherwise), like `IMAGE` items. Not yet supported
(validation error): `text`, gradients, `spline`/`arc`/`curve`/`dot`,
`shape`/`draw` blocks, `clip`, `effect`, and any transform
(`translate`/`scale`/`rotate`/`skew`/`matrix`).
`polygon` takes its points as **separate arguments** (Red's draw dialect rejects a
block form). A `line` is a **stroke** — it is drawn with `pen`; `fill-pen` has no
effect on it (validation flags a `line` drawn while `pen` is off).

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

- `text` inside DRAW, and inline-in-a-line DRAW (where `x` is the right edge of the
  previous value).
- `DRAW`/`IMAGE` inside a running `HEADER`/`FOOTER` (e.g. a logo on every page);
  header/footer are text-only today (§14.10). For a page-wide logo use `DRAW-BG`.
- `image` **inside DRAW is supported** (see §16.4) — it accepts an image, a file, or a
  word bound to either.

### 16.7 FRAME — a measured backdrop

`[FRAME R [items] [draw-ops]]` lays out its `items` (BODY text lines) to **measure**
them, then draws the `draw-ops` backdrop **behind** them. `R` is the padding around
the measured content box (integer, default 0). The items block comes **first**
because it is measured before the backdrop is drawn.

This is the way to fill behind a wrapping paragraph: `DRAW` runs after its element
and can only paint *on top*, and the paragraph's height isn't known until it is laid
out.

```red
[FRAME 8 [
    ["A paragraph that wraps, framed from behind." [b]]
    ["A second line." [m]]
] [
    pen 90.120.200  fill-pen 238.242.255  line-width 1
    box (as-pair x y) (as-pair x + w y + h) 6      ; rounded backdrop
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

### 16.8 AT — an absolute page overlay

`[AT x y [items]]` draws its `items` (BODY text lines and/or `IMAGE` items) at an absolute page
position: `(0,0)` is the **page's top-left**, independent of margins. It is an
**overlay**: it does not move the flow cursor, does not update `prev-*`, and the
flow continues as if the AT were not there. It cannot span a page break; its
contents must fit on the current page (an overflow warning is printed).

Coordinates are evaluated at **render** time, so `prev-*` and the page/cursor words
are available:

```red
[IMAGE px/180 %logo.png]
[AT (prev-x + prev-w + 16) prev-y [
    ["Text beside the logo" [b]]
    ["AT is an overlay; the flow continues below the image." [m]]
]]
[AT 20 20 [["TOP-LEFT" [f2 white red3]]]]        ; a stamp
```

Bound words in the coordinate expressions (page/draw space, top-down):

- `prev-x prev-y prev-w prev-h` — the box of the previous **flow** item on this page
  (`prev?` is false if there is none; using `prev-*` then is an error)
- `page-width page-height`, `margin-left/right/top/bottom`, `content-width`
- `cursor-x cursor-y` — where the next flow item would go

`x`/`y` may be two integer expressions or one pair, e.g. `[AT (as-pair 20 30) [...]]`.
The AT items wrap to `page-width - margin-right - x`.

Notes:

- AT is BODY-only; its items may be text lines or `IMAGE` items. They cannot
  contain `DRAW`/`FRAME`/`TABLE`/`COLUMN`/`PAGEBREAK` or another `AT`; `AT` is not
  allowed inside `COLUMN` or `FRAME`.
- AT lands on the page the flow is on when the item is reached; a stamp placed after
  a page break lands on the later page.
- `prev-*` resets at each page start and is never updated by `AT` itself.
- Use `AT` for logos/stamps/asides. Content that should reserve space belongs in the
  normal flow (or `FRAME`).

### 16.9 Parens, `compose/deep`, and DRAW

DRAW and DRAW-BG parens are evaluated at **render** time, with the page geometry in
scope (`page-width`, `page-height`, `margin-*`, and for DRAW the cursor/`prev-*`
words). Everything else is composed at **parse** time by `parse-report` (§11.1). The
parser knows about draw items, so it composes the report while leaving the ops blocks
alone — you just write the report literally:

```red
report: [ margin/20
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
report: [ margin/20  [DRAW-BG 3 bg]  [BODY [["…"]]] ]
```

The same holds for `[DRAW H ops]`. Geometry stays in one place (the renderer) — nothing
about page size is duplicated at build time.

---

*This document supersedes `pdf-reports/new-syntax-proposal.txt`. The demo reports
(`Test-Report.red`, `Simple-Report.red`, `Long-Report.red`) are the living
examples of the v2 dialect and should be kept in sync with this spec.*
