# Report DSL — cheat sheet

Quick “what may I write here?” reference, aligned with the current parser/renderers
(`libs/report-*.red`). Full detail: [`report-syntax-spec.md`](report-syntax-spec.md).

---

## 1. Four kinds of blocks

The **first element** decides what a block is:

| First element | Block kind | Example |
|---|---|---|
| a word that is a known keyword (case-insensitive) | **keyword item** | `[BODY [ … ]]` |
| a block made only of styles (no strings, no nested blocks) | **style block** | `[b red px/80]` |
| anything else (string, number, paren, date, `none`, or a leading style block) | **line block** | `["Hello" [b]]` |

- A line starting with a **style block** is still a line; that block styles the whole line.
- A line whose first value is a bare word equal to a keyword (`HEADER`, `TABLE`, …) is
  parsed as a keyword item. To print such a word, quote it: `["HEADER" …]`.
- Keywords are case-insensitive bare words (`BODY`, `body`, `'body` all work).

---

## 2. Report skeleton

```red
[
    ; --- optional paper clause (leading words / pair) ---
    a4  landscape  margin/20  top/25  right/15  …

    [DRAW-BG 3 [ …raw draw… ]]          ; optional, behind every page
    [HEADER style-words? [lines] [lines2]?]   ; optional
    [BODY   style-words? [items]]             ; required
    [FOOTER style-words? [lines] [lines2]?]   ; optional
]
```

**Paper clause** (any order, last size/orientation wins):

| Form | Meaning |
|---|---|
| `a4` `a5` `a3` `letter` `legal` | paper name (default `a4`) |
| `600x800` | custom size in points (WxH) |
| `landscape` / `portrait` | orientation (default portrait) |
| `margin/20` | uniform margin, all four sides (default 50) |
| `top/20` `bottom/10` `left/15` `right/15` | one side; always overrides `margin/N`, in any order |

Paths are the only accepted spelling: `margin/20`, `top/20`, `px/80`, `ss/9`.
Legacy `-N` words (`margin-20`, `px-80`, `ss-9`) and `#Npx`/`#Nch` width tags are
rejected with a “use path notation” message.

---

## 3. Keyword items

`[KEYWORD args… [block]?]` — args are collected up to the first block; trailing block optional.
Args are matched **by type, not position**; a modifier carries its optional value as a
`/N` suffix (`border/2`, `shadow/5`, `gap-ch/4`). Widths are **always explicit** —
`px/N` or `ch/N` (or `auto` for a COLUMN); bare integers are rejected as ambiguous.

| Keyword | Allowed in | Arguments | Trailing block |
|---|---|---|---|
| `HEADER` / `FOOTER` | page level | style words | text lines + optional 2nd lines block (page 2+) |
| `HEADER` / `FOOTER` | inside `BODY` | style words | text lines → running override from **next page on** |
| `BODY` | page level | style words | items |
| `DRAW-BG` | page level | optional integer = raster density | raw draw ops |
| `TABLE` | `BODY` | `BOX`/`ALT` (any order) + style words | rows; **first row = header + column spec** |
| `COLUMN` | `BODY` | width? (`px/N`/`ch/N`/`auto`) `gap-ch/N`|`gap-px/N`? style-words? [`image` `[img-styles]`]? | rows (lines / `IMAGE` / `PAGEBREAK`) |
| `IMAGE` | `BODY`, `COLUMN` | width? (shadow\|border)(/N)? colour? source | optional caption line `["cap" [styles]]` |
| `PAGEBREAK` | `BODY`, `COLUMN`, `TABLE` rows | optional integer = reserve n lines | — |
| `DRAW` | `BODY` | optional integer `H` (points consumed) | raw draw ops |
| `FRAME` | `BODY` | optional integer padding | `[draw ops]` then `[items]` |
| `TOC` | `BODY` | style words | pattern lines |

Notes:

- **`COLUMN`**: first arg is always the width (`N`/`ch/N`/`px/N`/`auto`, default auto),
  second is the gap (only if width is present — use `auto` to set just a gap),
  remaining style words style **line rows only**. `image [styles]` styles contained images.
- **`IMAGE`**: a bare numeric width is **px** (unlike `COLUMN`, where it is `ch`).
  Args: `width? (shadow|border)(/N)? colour? source`, **matched by type (order
  irrelevant)**, so the caption style block stays pure text styles/colours.
  *source* may be a `file!`/`string!` path **or an `image!`** (e.g. generated via a paren:
  `(make image! reduce [200x100 0.128.255])`). File sources default the caption to the
  file stem; an `image!` has no name, so it gets no caption unless one is supplied.
- **`HEADER`/`FOOTER`** are drawn line-by-line (positional, see §6). Keep them to text
  lines; other item kinds are not supported there by the renderer.
- **In-body `HEADER`/`FOOTER`** take effect from the next page; `[]` clears them.

---

## 4. Line blocks

```red
[ style-block?  value style-block?  value style-block?  … ]
```

- **Leading style block** = base style for every value on the line.
- Each value may be followed by its **own style block**, merged on top of the line style.
- Values: `string` `number` `date` `tag` or `none` (empty). Computed values go in a
  paren: `(now)`, `(total)`. A bare word is rejected (except `none`).
- `[]` (empty block) is a **blank line** — same as `[""]`.
- Multi-segment lines flow left→right (**BODY text wraps** at the content width;
  `nowrap` disables it). Tables/columns/header/footer do **not** wrap.
- **Header/footer lines are positional instead**: 1st value left, 2nd centred,
  3rd right, extras left (§6).

---

## 5. Style blocks

```red
[b i u s/10 ss/9 m/8 red 255.0.0 px/80 > money]
```

### 5.1 Font family / size / level / decoration

| Atom | Effect |
|---|---|
| `s` / `ss` / `m` | serif (default) / sans / monospace |
| `s/N` `ss/N` `m/N` | family **and** size N in one atom (e.g. `ss/9`) |
| `word/N` | any style word with size N: `i/8`, `b/9`, `h2/20`, … |
| `b` `i` `u` | bold, italic, underline |
| `!b` `!i` `!u` `!m` `!s` `!<` … | cancel that attribute inherited from any higher level |
| `h1` `h2` `h3` | levels: 2× / 1.5× / 1.17× of base, bold — **and TOC markers** |
| `f1` `f2` `f3` | same sizes/bold as h1-h3, **style only** (no TOC) |
| `f4` | reset to base size, not bold |

### 5.2 Alignment

| Atom | Meaning |
|---|---|
| `<` `^` `>` | left / centre / right |

Default is left. A **numeric** value with a width box defaults to right.
In a BODY line segments chain left→right; `< ^ >` only shift **inside a width box**.
Header/footer use positional L/C/R and ignore these.

### 5.3 Formatting / width

| Atom | Meaning |
|---|---|
| `money` | `$1,234.56` |
| `s1000` | thousands separators, no decimals |
| `w.d` (float, on a number) | `d` decimals; box width `w` characters |
| `date` `time` `datetime` | format a `date!` value (or `<now>`) |
| `blank` | table cells only: suppress `0` |
| `ch/N` | width box of N **average characters** of this style |
| `px/N` | width box of N **pixels** |
| `auto` | `COLUMN` width only |

A bare integer is **not** a width — validation rejects it (use `ch/N` or `px/N`).

A width box reserves space; the next segment starts at its right edge. If the text is
wider, the text wins (no truncation).

### 5.4 Colours

Tuples (`255.165.0`) or colour words (`red`, `blue`, `coffee`, …). Order defines the role:

| Order | Role |
|---|---|
| 1st colour | font |
| 2nd colour | background |
| 3rd colour | frame/border |

### 5.5 Interactive (View only)

| Atom | Meaning |
|---|---|
| `link/N` | click hotspot (id N); implies solid underline |
| `hint/N` | hover hint (id N); implies dotted underline |

`!u` suppresses the implied underline. In `IMAGE` captions a `link/N`/`hint/N` makes the
whole image area interactive.

### 5.6 IMAGE box clause

IMAGE args are matched **by type, not position**:

`[IMAGE width? (shadow|border)(/N)? colour? source]`

- `shadow` = drop shadow, `border` = frame box;
- `/N` = inset in points (default 5% of the image width), attached to the word —
  `border/2`, `shadow/5`, like `ss/8`;
- optional box colour (default `silver`).

A bare integer is always the image **width**, so order is irrelevant:
`[IMAGE 120 shadow/3 silver %f]` ≡ `[IMAGE shadow/3 silver 120 %f]`.
Omit the width for intrinsic sizing (`auto` is not used for `IMAGE`).

The **caption** style block is pure text styles + 1-3 colours (font, background, frame) and
`link/N`/`hint/N` — no box words. (Old reports with `shadow`/`border` in the caption style
block still parse.)

---

## 6. Header / footer

- Segments are **positional**: 1st = left, 2nd = centre, 3rd = right, more = left.
- A segment with no style falls back to **bold**.
- Footer lines are stacked from the bottom margin upward.
- `[HEADER [ … ] [ … ]]`: 2nd block is shown from **page 2** on; `[]` = none from page 2.
- In-body `[HEADER […]]` / `[FOOTER […]]`: **running override from the next page onward**;
  the current page keeps its header/footer.

---

## 7. Tokens

| Token | Replaced with |
|---|---|
| `<page>` | current page number |
| `<pages>` | total pages |
| `<now>` | date/time per style: `[date]`/`[time]`/`[datetime]` (default datetime) |
| `%DATE%` `%TIME%` `%DATETIME%` | legacy equivalents |

`<now>` works inside a string (`"Time: <now>" [time]`) or as a pure tag value (`<now> [date]`).
Tokens are currently replaced **everywhere** (header, body/content, footer) by both renderers.
There is no escape for literal `<page>`/`<now>` in body data.

---

## 8. Table of contents

- `h1`/`h2`/`h3` render like `f1`/`f2`/`f3` **and** register a heading.
- `[TOC [pattern lines]]` in `BODY` expands after pagination, in **document order**.

```red
[TOC [
    ["<h1>"       [f2 px/300]     "<t-page>" [f2]]
    ["    <h2>"   [f2 px/300]     "<t-page>" [f2]]
    ["        <h3>" [s/12 px/300] "<t-page>" [s/12]]
]]
```

- `<h1>/<h2>/<h3>` in a pattern line → its heading text (one line per heading of that level).
- `<t-page>` → that heading's page number.
- A level is listed **only if a pattern line for it exists**. A pattern line with no
  placeholder is emitted literally (a caption).
- `px/N` on the text segment keeps the filled-in page number from re-wrapping.

---

## 9. Raw draw (`DRAW`, `DRAW-BG`, `FRAME`)

Allowed commands (anything else is rejected by validation for `DRAW`/`FRAME`):

| Kind | Commands |
|---|---|
| state | `pen <tuple|off>` `fill-pen <tuple|off>` `line-width` `line-join` `line-cap` `anti-alias` |
| shapes | `box p1 p2 [radius]` `circle c r` `ellipse c r` `line p1 p2` `triangle p1 p2 p3` `polygon p1 p2 …` |
| image | `image <src> p1 p2` or `image <src> pos` (natural size) |

- `<src>`: an `image!`, a `file!` (auto-loaded), or a word bound to either.
- `p1`/`p2` are **corners** (the image is scaled into the box), not size.
- In the View, coordinates are page draw space (origin top-left, y down).
- `DRAW H [ops]`: `H` = points consumed (0 allowed; omit to measure literal ops).
- Coordinates/words available in ops: `x y w h prev-x prev-y prev-w prev-h prev?`
  `page-width page-height margin-left/right/top/bottom`.
- Not supported: `text`, gradients, `spline/arc/curve/dot`, transforms, `clip`, `effect`.
- `DRAW-BG` is rasterised for PDF (needs Red/View); under headless `red` it is omitted.

---

## 10. Units

Widths are always explicit — a bare integer is rejected as ambiguous.

| Tag | Meaning |
|---|---|
| `px/N` | N pixels |
| `ch/N` | N average characters of the style |
| `gap-ch/N` | COLUMN gap in average characters |
| `gap-px/N` | COLUMN gap in pixels |
| `w.d` (float) | number format: box w chars, d decimals |

Applies to COLUMN width, IMAGE width, table header-row cell width and line-segment width
boxes. No context has a default unit any more.

---

## 11. Evaluation model

- **Parens are evaluated at build time:** `(now)`, `(total)`, `(rejoin […])`.
  Inside raw-draw ops, parens are deferred and evaluated by the renderer (so `(load %x)`
  and `x`/`y` references work).
- Use `compose/deep` to splice computed blocks (e.g. a generated list of rows).
- Unknown leading paper words and unknown style words fail `validate-report`.
- A bare word used as a value is rejected (`none` is the exception).

---

## 12. Gotchas checklist

- [ ] Widths need a unit: `px/N` or `ch/N`; COLUMN gap is `gap-ch/N` or `gap-px/N`.
- [ ] Legacy `-N`/`#Npx` forms are rejected — write paths.
- [ ] Table **first row is the header and defines columns**.
- [ ] Colours are positional (font, background, frame), wherever they sit in the block.
- [ ] `!X` cancels an inherited attribute; it is not “reset to default”.
- [ ] A data line starting with a keyword word is parsed as that keyword — quote it.
- [ ] `[]` is a blank line; an empty *items* block is `[BODY []]`.
- [ ] Header/footer lines are positional L/C/R; BODY lines flow left→right.
- [ ] `<page>/<pages>/<now>` expand in body text too (no escape).
- [ ] `h*` = style **and** TOC marker; use `f*` for style only.
- [ ] `DRAW-BG` needs Red/View (omitted in headless PDF output).

---

## 13. Cookbook

```red
; one line, mixed styles
["Total: " [b] 42.5 [money] "  due " (now) [date red]]

; a heading + text
["Chapter 1" [h1]]
["Body text wraps automatically and can be " [i] "styled inline" [b red]]

; blank spacer
[]

; page break
[PAGEBREAK]

; table: header row defines columns (widths explicit)
[TABLE BOX ALT [
    ["Name" ch/20] ["Qty" ch/5 >] ["Price" ch/8 >]
    ["Widget" 20] [3 ch/5 >] [12.50 ch/8 > money]
]]

; two-column flow, gap 2 chars
[COLUMN auto gap-ch/2 [ ["row 1"] ["row 2"] ]]

; image with caption and shadow
[IMAGE px/160 shadow/3 silver %logo.png ["Logo" [b]]]

; header/footer with page tokens; alt header on page 2+
[HEADER [["Report" [f2]] ["Page <page> of <pages>" "" (now) [date]]]]
[FOOTER [["Draft"]][["Page <page> of <pages>"]]]

; running header change from page 3 on
[HEADER [["Section 2" [f2]]]]

; TOC
[TOC [["<h1>" [f2 px/300] "<t-page>" [f2]]]]

; raw art
[DRAW 40 [pen 0.0.160 fill-pen 235.242.255 line-width 2
          box (as-pair x y) (as-pair (x + 80) (y + 30)) 6]]
```
