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
4. **Styles are per-value** — every value on a line carries its own optional style block; there are no line-wide styles.

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

## 4. Items

Every item is a block. Its first element decides the shape — a *known word*
makes it a keyword item, anything else makes it a *line*:

```text
item        := keyword-item | line-item

keyword-item := [ known-word args… [items]? ]   ; trailing items block optional
known-word   := HEADER | BODY | FOOTER | TABLE | COLUMN | IMAGE | PAGEBREAK
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
  grammar from §4.4; it may carry a **default image width** (`#Npx`/`#Nch`, e.g.
  `image [#80px shadow 3 silver]`). Generics and the image clause may both be present
  (`[COLUMN b image [#80px shadow 3 silver] rows]`): text rows get `b`, images the image styles.
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

`[IMAGE file]`  |  `[IMAGE file [caption [styles]]]`

- *file* — a `file!` or `string!` path. **There is no width argument** — the display width is
  carried in the style block as `#Npx` / `#Nch`.
- *width* — optional `#Npx` / `#Nch` at the start of the style block. When omitted the image uses
  its **intrinsic width, contained to the available height and width** (proportions kept).
  Inside a `COLUMN` a width-less image is contained to the column width (see §4.3).
- *file* — a `file!` or `string!` path.
- The optional trailing block is the image's **caption line** — exactly one value + a style block.
- *caption* — a `string!`, drawn **centered one line below** the image. When the caption line is
  omitted, the caption defaults to the **file's name without extension** (`Empress.jpg` → `Empress`);
  a `""` value gives **no caption**.
- *styles* (the caption's style block) — IMAGE-specific grammar, in order:
  1. optional **width** `#Npx` / `#Nch` (see *width* above), then optional `shadow` or `border` —
     `shadow` = drop shadow (base and image the same size, the base offset down-right); `border` = a frame box;
  2. optional **integer** — the inset / offset in points (**defaults to 5% of the image width**);
  3. optional **color** — the shadow/border colour (default `silver`); the **first** colour after
     `shadow`/`border` is consumed as the box colour;
  4. the remaining words are the caption's **text styles** (`b i u s m h1-h3`, `link-N`, `hint-N`,
     `!X`) and the trailing 1–3 **colours** (font, background, frame) — as on a line.
     `link-N`/`hint-N` make the **whole image area** an interactive hotspot (the caption is the
     popup text, `N` the id); `link-N` implies a solid underline, `hint-N` a dotted one (View-only).
- Examples:
  - `[IMAGE %tutorials/thumbs/Empress.jpg]` — intrinsic width contained to the page; caption `Empress`.
  - `[IMAGE %tutorials/thumbs/Empress.jpg ["Empress" [#120px shadow 3 red link-1]]]` — 120 px, shadow, red box, linked.
  - `[IMAGE %tutorials/thumbs/Empress.jpg ["Empress" [border 3 silver]]]` — intrinsic width, silver frame box.
  - `[IMAGE %tutorials/thumbs/Empress.jpg ["Empress" [b red blue]]]` — no box; bold caption, red on blue.
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
| `s` | sans-serif font |
| `m` | monospace font |
| `h1` / `h2` / `h3` | heading levels, font sizes 24 / 18 / 14 pt |

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
automatically — unless `!u` is present (which suppresses the underline).
These auto-underlines are **View-only**: the PDF drops links/hints entirely and so does
not auto-underline them (an explicit `u` still underlines).

The handler signature is `func [type [word!] id [word! number!] text [string!]]`
(Red 0.6.6 has no distinct runtime `lit-word!` — `'link`/`'hint` arrive as `word!`,
so a `[lit-word!]` parameter rejects them).
The **PDF renderer silently drops** links and hints (§13).

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

Reports are normally *pre-composed* with `compose/deep`, e.g. `(now)`, `(total)`,
`(widget-C)`. The parser also has a safety net: a paren that survives to
parse time is `do`-evaluated and, if it yields a block, spliced as items. Pre-composing
is the recommended, deterministic path.

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
the first problem (unknown keyword, malformed `IMAGE`/`COLUMN`/`TABLE`, bad width
tags, non-block table rows, …). The demo reports all pass validation (verified).

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
```

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

*This document supersedes `pdf-reports/new-syntax-proposal.txt`. The demo reports
(`Test-Report.red`, `Simple-Report.red`, `Long-Report.red`) are the living
examples of the v2 dialect and should be kept in sync with this spec.*
