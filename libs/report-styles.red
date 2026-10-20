Red [
    File:      %report-styles.red
    Title:     "Style Helpers"
    Purpose:   {Shared style interpretation, color handling,
                formatting, and layout math for the compact
                report parser. Used by both the PDF generator
                and the View renderer.}
    Date:      2026-08-19
    Tabs:      4
    Note:      {Ported from report-generator/report-common.red.
                Adapted for the compact parser's pair format
                [[val style?] ...]. No line-wide styles —
                merge-styles and parse-line are removed.}
]

report-styles: context [
    ;=== Page geometry (A4 default, all values in PostScript points) ===

    page-width:  595
    page-height: 842
    margin-left:   50
    margin-right:  50
    margin-top:    50
    margin-bottom: 50
    edge-pad:       1

    ;=== Typography ===

    font-size:           12
    line-height-factor:  1.6
    ; spacing for lines whose largest size is above the base size (headings or
    ; big /N sizes) — lower it if large fonts get too much leading
    line-height:         to integer! (font-size * line-height-factor)
    base-styles:         copy []   ; global base font styles (see make-font)
    row-padding:          4
    cell-pad:             3
    underline-offset:     2
    stroke-width:         0.5

    ;=== Unit helpers ===

    width-spec-px: func [
        {Width spec -> page px. A number is N * char-px; px/N -> N; ch/N -> N * char-px.
         Accepts the normalized word (px-80), a path (px/80), or a legacy issue. 0 if unknown.}
        spec [any-type!] char-px [number!]
        /local ss s u n
    ][
        case [
            none? spec [0]
            number? spec [to integer! (spec * char-px)]
            all [any [word? spec path? spec]  ss: size-suffix to word! spec][
                either ss/1 = 'ch [to integer! (ss/2 * char-px)][ss/2]
            ]
            issue? spec [
                s: form spec
                u: none  n: none
                case [
                    find/match s "px-" [u: 'px  n: to integer! skip s 3]
                    find/match s "ch-" [u: 'ch  n: to integer! skip s 3]
                    find/match s "px"  [u: 'px  n: to integer! skip s 2]
                    find/match s "ch"  [u: 'ch  n: to integer! skip s 2]
                    find s "px"        [u: 'px  n: to integer! copy/part s ((length? s) - 2)]
                    find s "ch"        [u: 'ch  n: to integer! copy/part s ((length? s) - 2)]
                ]
                either u [to integer! either u = 'ch [n * char-px][n]][0]
            ]
            true [0]
        ]
    ]

    width-to-px: func [
        "Normalize a width spec to page units (px). Bare number -> default-unit ('ch or 'px). px/N / ch/N -> explicit units."
        spec [any-type!] default-unit [word!]
    ][
        width-spec-px spec either default-unit = 'ch [font-size * 0.5][1]
    ]

    ;=== Grayscale fills ===

    header-gray:    0.85
    alt-row-gray:   0.95

    default-col-width: 12

    ;=== Supported paper sizes (width x height in points) ===

    paper-sizes: [
        a4     [595  842]
        letter [612  792]
        legal  [612 1008]
        a3     [842 1190]
        a5     [420  595]
    ]

    landscape?: false

    ;=== Configuration ===

    fontsize: func [
        "Set font size and recalculate line height"
        size [integer!] "Font size in points"
    ][
        font-size: size
        line-height: to integer! (font-size * line-height-factor)
    ]

    make-font: func [
        {Set the report's global base font: familiar style words (b i u s m h1-h3,
         link/N, colours) and a size in points. It applies to every value; per-line
         and per-value styles merge on top and !X drops a base style, so callers can
         still override it locally. One call configures the View and PDF renderers
         and the shared report-styles copy the parser reads, so calling it on either
         renderer (report-view/make-font ... / report-pdf/make-font ...) is enough.
         /line sets the line-spacing factor (line height = rendered base size x
         factor) in the same call, e.g. report-view/make-font/line [m] 11 1.6.}
        styles [block!] sz [integer!]
        /line factor [number!]
        /local lh
    ][
        if line [
            line-height-factor: factor
            report-styles/line-height-factor: factor
            if value? 'report-view [report-view/line-height-factor: factor]
            if value? 'report-pdf  [report-pdf/line-height-factor: factor]
        ]
        lh: to integer! (sz * line-height-factor)
        ; the renderer this was called on (or report-styles itself)
        base-styles: copy styles
        font-size: sz
        line-height: lh
        ; the shared copy the parser reads
        report-styles/base-styles: copy styles
        report-styles/font-size: sz
        report-styles/line-height: lh
        ; the sibling renderer, so a single call is global
        if value? 'report-view [
            report-view/font-size: sz
            report-view/line-height: lh
        ]
        if value? 'report-pdf [
            report-pdf/font-size: sz
            report-pdf/line-height: lh
        ]
    ]

    reset-font: func [
        {Restore the default base font (serif, 12 pt) on this and sibling renderers,
         so one report's make-font cannot leak into the next report in the process.}
        /local d
    ][
        d: to integer! (12 * line-height-factor)
        base-styles: copy []
        font-size: 12
        line-height: d
        report-styles/base-styles: copy []
        report-styles/font-size: 12
        report-styles/line-height: d
        if value? 'report-view [
            report-view/font-size: 12
            report-view/line-height: to integer! (12 * report-view/line-height-factor)
        ]
        if value? 'report-pdf [
            report-pdf/font-size: 12
            report-pdf/line-height: to integer! (12 * report-pdf/line-height-factor)
        ]
    ]

    paper-format: func [
        "Set paper size by name or custom pair (e.g. 595x842). Returns none if unknown name."
        name-or-size [word! pair!] "Name (a4 letter legal a3 a5) or size in points (WxH)"
        /landscape "Swap width and height for horizontal orientation"
        /local sz
    ][
        either pair? name-or-size [
            landscape?: landscape
            either landscape [
                page-width: name-or-size/y
                page-height: name-or-size/x
            ][
                page-width: name-or-size/x
                page-height: name-or-size/y
            ]
        ][
            sz: select paper-sizes name-or-size
            either sz [
                landscape?: landscape
                either landscape [
                    page-width: sz/2
                    page-height: sz/1
                ][
                    page-width: sz/1
                    page-height: sz/2
                ]
            ][
                print rejoin ["Unknown paper format: " name-or-size ". Valid: " mold words-of paper-sizes]
                none
            ]
        ]
    ]

    ;=== Color helpers ===

    style-fg-color: func [
        "Extract first tuple from styles as font color, or none"
        styles [block!]
        /local s
    ][
        foreach s styles [if tuple? s [return s]]
        none
    ]

    opaque-tuple?: func [
        "True when a tuple is opaque. Red 4-tuples are RGBA (alpha first), so 0.0.0.255 is transparent and must not be painted."
        c [tuple!]
    ][
        case [
            (length? c) >= 4 [c/1 > 0]
            true [true]
        ]
    ]

    style-bg-color: func [
        "Extract second tuple from styles as background color, or none"
        styles [block!]
        /local s count
    ][
        count: 0
        foreach s styles [
            if tuple? s [
                count: count + 1
                if count = 2 [return s]
            ]
        ]
        none
    ]

    style-frame-color: func [
        "Extract third tuple from styles as frame color, or none"
        styles [block!]
        /local s count
    ][
        count: 0
        foreach s styles [
            if tuple? s [
                count: count + 1
                if count = 3 [return s]
            ]
        ]
        none
    ]

    ; Style words are never colors; a colour word anywhere in the block is
    ; resolved to its tuple (colours may be interleaved with other styles).
    style-words: [b i u s m ss h1 h2 h3 f1 f2 f3 f4 < > ^ blank money s1000 date time datetime shadow border wrap nowrap !u]

    resolve-colors: func [
        "Resolve every colour word in a style block to a tuple, wherever it appears"
        styles [block!]
        /local result i s val
    ][
        result: copy styles
        i: 0
        foreach s result [
            i: i + 1
            if all [word? s  not find style-words s][
                val: attempt [get s]
                if tuple? :val [poke result i val]
            ]
        ]
        result
    ]

    ;=== Style helpers ===

    style-has: func ["Check if style block contains target word" styles [block!] target [word!]][
        not none? find styles target
    ]

    style-underline-type: func [
        "Underline style: 'solid | 'dotted | 'none. An explicit u wins; otherwise link/N -> 'solid, hint/N -> 'dotted, unless !u."
        styles [block!]
        /explicit
        /local ws
    ][
        if find styles 'u [return 'solid]
        if find styles '!u [return 'none]
        if not explicit [
            foreach ws styles [
                if all [word? ws (length? form ws) >= 6][
                    switch copy/part form ws 5 [
                        "link-" [return 'solid]
                        "hint-" [return 'dotted]
                    ]
                ]
            ]
        ]
        'none
    ]

    style-underline-shown?: func [
        {Should an underline be drawn? An explicit u always is; an implicit link/hint
         underline is hidden when the run has an opaque background (the background
         already marks the run, and the underline would collide with the row below).}
        styles [block!]
        /local ut bg
    ][
        ut: style-underline-type styles
        if ut = 'none [return false]
        if find styles 'u [return true]
        bg: style-bg-color styles
        not all [bg opaque-tuple? bg]
    ]

    norm-style-atom: func [
        {Normalise a style atom: a 2-component path (ss/9, px/80, link/2) is turned
         into its dash-word form (ss-9, px-80, link-2); any other value is returned
         unchanged. Style atoms can arrive as paths when a style block is produced by
         a runtime paren (composed after the parser's norm-arg pass).}
        s [any-type!]
        /local p
    ][
        unless path? s [return s]
        p: s
        if (length? p) <> 2 [return s]
        unless all [any [word? p/1 integer? p/1]  any [word? p/2 integer? p/2]][return s]
        to word! rejoin [form p/1 "-" form p/2]
    ]

    style-split: func [
        {Split a style block into [directives colors]. Colours are every tuple or
         colour word in the block, in order, wherever they appear; directives are
         the remaining atoms, in order.}
        st [block!]
        /local dir col s
    ][
        dir: copy []
        col: copy []
        foreach s st [
            ; a path! must not be appended bare: append would splice it into its
            ; components (ss/9 -> ss 9), leaking a bare integer width downstream
            s: norm-style-atom s
            either any [tuple? s  all [word? s  tuple? attempt [get s]]][
                append/only col s
            ][
                append/only dir s
            ]
        ]
        reduce [dir col]
    ]

    font-size-suffix: func [
        {Split a font-size style word like i-8 / b-9 / m-10 / ss-12 into [base size];
         none when the word is not a sized style/family word. Width words (px-80,
         ch-20) and ids (link-2, hint-2) are not font sizes.}
        w [word!]
        /local ss
    ][
        ss: size-suffix w
        if none? ss [return none]
        if any [find style-words ss/1  not none? family-of ss/1][return ss]
        none
    ]

    width-style-atom?: func [
        "True for an atom that sets a width: a bare integer, px/N / ch/N, or px-N / ch-N."
        s [any-type!]
        /local ss
    ][
        case [
            integer? s [true]
            issue? s [true]
            all [word? s  ss: size-suffix s  find [px ch] ss/1][true]
            true [false]
        ]
    ]

    merge-styles: func [
        "Merge a line (base) style with a per-value style: per-value wins on colors, alignment, family, size, heading, format, width; decorations (b i u ...) are additive."
        base [block!] extra [block!]
        /local bs es bd bc ed ec ov out s has-width? ndrops new-bd
               fam fss xfam xsize newfam newsize keep cleaned w fssw redundant
    ][
        bs: style-split base
        es: style-split extra
        bd: bs/1  bc: bs/2
        ed: es/1  ec: es/2
        ; a '!X' in extra drops X from the base (from all higher levels)
        ndrops: copy []
        foreach s ed [
            if all [word? s (length? form s) >= 2 (first form s) = #"!"][
                append ndrops to word! copy skip form s 1
            ]
        ]
        if not empty? ndrops [
            new-bd: copy []
            foreach s bd [unless find ndrops s [append new-bd s]]
            bd: new-bd
        ]
        ; keep the '!X' tokens in the result so downstream style readers (e.g.
        ; style-underline-type) can still see an explicit negation
        if empty? ed [
            ; extra has no directives (only colors and/or negations): base directives
            ; plus the extra color if any, else the base color
            return append copy bd either empty? ec [bc][ec]
        ]
        ; family and font-size the extra defines (the first of each wins). The
        ; family is stored as its token (s / m / ss) so it can be recombined with a size.
        xfam: none  xsize: none
        foreach s ed [
            if word? s [
                unless xfam [
                    if family-of s [
                        xfam: either fss: font-size-suffix s [fss/1][s]
                    ]
                ]
                unless xsize [
                    if fss: font-size-suffix s [xsize: fss/2]
                ]
            ]
        ]
        ; categories extra defines, which replace the base's
        ov: copy []
        if any [find ed '< find ed '> find ed '^][append ov [< > ^]]
        if any [find ed 'h1 find ed 'h2 find ed 'h3 find ed 'f1 find ed 'f2 find ed 'f3 find ed 'f4][
            append ov [h1 h2 h3 f1 f2 f3 f4]
        ]
        if any [find ed 'money find ed 's1000 find ed 'date find ed 'time find ed 'datetime find ed 'blank][
            append ov [money s1000 date time datetime blank]
        ]
        has-width?: false
        foreach s ed [if width-style-atom? s [has-width?: true]]
        out: copy []
        foreach s bd [
            fam: none  fss: none
            if word? s [
                fam: family-of s
                fss: font-size-suffix s
            ]
            keep: true
            case [
                ; a base family word: fold in the extra's family and/or size, so a
                ; value can override the family, the size, or both (e.g. s-10 -> ss-7)
                all [fam any [xfam xsize]] [
                    newfam: any [xfam either none? fss [s][fss/1]]
                    newsize: any [xsize either fss [fss/2][none]]
                    append out either newsize [
                        to word! rejoin [form newfam "-" newsize]
                    ][
                        newfam
                    ]
                    keep: false
                ]
                ; a base sized non-family word (e.g. i-8): fold in the extra's size
                all [fss xsize] [
                    append out to word! rejoin [form fss/1 "-" xsize]
                    keep: false
                ]
            ]
            if keep [
                unless any [
                    find ov s
                    all [has-width? width-style-atom? s]
                ][append out s]
            ]
        ]
        foreach s ed [unless find out s [append out s]]
        ; drop a bare family word (s/m/ss) when a sized form of it is already present
        cleaned: copy []
        foreach s out [
            redundant: false
            if all [word? s  family-of s  none? font-size-suffix s][
                foreach w out [
                    if all [word? w  fssw: font-size-suffix w  fssw/1 = s][redundant: true  break]
                ]
            ]
            unless redundant [append cleaned s]
        ]
        append cleaned either empty? ec [bc][ec]
        cleaned
    ]

    to-id: func [
        "Convert a link/hint id to a number (if numeric), a word, or the string itself"
        s [string!]
        /local v
    ][
        either v: attempt [to integer! s][
            v
        ][
            v: attempt [to word! s]
            either v [v][s]
        ]
    ]

    style-align: func [
        "Extract alignment from styles ('< = L, '^ = C, '> = R), or return default"
        styles [block!] default [string!]
    ][
        case [
            find styles '< ["L"]
            find styles '^ ["C"]
            find styles '> ["R"]
            true [default]
        ]
    ]

    style-width: func ["Extract integer width from styles, or 0" styles [block!] /local s][
        foreach s styles [if integer? s [return s]]
        0
    ]

    ;--- Character-width model -------------------------------------------------
    ; A bare integer or 'ch/N' on a line segment means N *average characters* in
    ; that segment's style/font: the average is measured over the alphabet below,
    ; so it is a property of the style, not of the value's text. 'px/N' is literal.
    alphabet: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

    style-width-px: func [
        "Literal pixel width from a px/N style (or the legacy px/N tag), or 0"
        styles [block!]
        /local s u ss
    ][
        foreach s styles [
            case [
                issue? s [
                    u: copy/part skip tail (form s) -2 2
                    if u = "px" [return to integer! copy/part form s ((length? form s) - 2)]
                ]
                all [word? s  ss: size-suffix s  ss/1 = 'px][return ss/2]
            ]
        ]
        0
    ]

    style-float: func [
        "First float style (number format width.decimals), or none"
        styles [block!]
        /local s
    ][
        foreach s styles [if float? s [return s]]
        none
    ]

    style-chars: func [
        {Character count for a width box from a ch/N style (or legacy ch/N tag), or the
         width part of a float (w.d -> w); or 0. Bare integers are ambiguous and rejected
         by validation — use ch/N or px/N.}
        styles [block!]
        /local s u f dpos n ss
    ][
        foreach s styles [
            case [
                float? s [
                    f: form s
                    dpos: find f #"."
                    n: attempt [to integer! either dpos [copy/part f dpos][f]]
                    if all [n n > 0][return n]
                ]
                all [word? s  ss: size-suffix s  ss/1 = 'ch][return ss/2]
                issue? s [
                    u: copy/part skip tail (form s) -2 2
                    if u = "ch" [return to integer! copy/part form s ((length? form s) - 2)]
                ]
            ]
        ]
        0
    ]

    style-align-for: func [
        {Alignment for a value/style pair: explicit '< ^ > wins; otherwise left,
         except a numeric value that has a width box defaults right (numbers read
         best right-aligned in their box, so decimal points line up).}
        val [any-type!] styles [block!]
        /local box?
    ][
        case [
            find styles '< ["L"]
            find styles '^ ["C"]
            find styles '> ["R"]
            true [
                box?: any [(style-width-px styles) > 0 (style-chars styles) > 0]
                either all [number? val box?]["R"]["L"]
            ]
        ]
    ]

    style-heading: func ["Return heading level (1-3) from h1/h2/h3 (table-of-contents markers), or 0" styles [block!] /local s ss b][
        foreach s styles [
            if word? s [
                ss: size-suffix s
                b: either ss [ss/1][s]
                if find [h1 h2 h3] b [return case [b = 'h1 [1] b = 'h2 [2] true [3]]]
            ]
        ]
        0
    ]

    style-level: func [
        {Styling level (1-4) from h1/h2/h3 or f1/f2/f3/f4: forces the heading size
         (1=2x, 2=1.5x, 3=1.17x, 4=1x) and, for 1-3, bold. h* also mark TOC entries;
         f* are the style-only equivalents. Returns 0 when absent.}
        styles [block!]
        /local s ss b
    ][
        foreach s styles [
            if word? s [
                ss: size-suffix s
                b: either ss [ss/1][s]
                case [
                    find [h1 f1] b [return 1]
                    find [h2 f2] b [return 2]
                    find [h3 f3] b [return 3]
                    b = 'f4 [return 4]
                ]
            ]
        ]
        0
    ]

    heading-size: func [
        "Font size for a style level, scaled from the base font size (1=2x, 2=1.5x, 3=1.17x, 4/0=1x)"
        hd [integer!]
    ][
        case [
            hd = 1 [to integer! (font-size * 2.0)]
            hd = 2 [to integer! (font-size * 1.5)]
            hd = 3 [to integer! (font-size * 1.1667)]
            true   [font-size]
        ]
    ]

    size-suffix: func [
        "Split a sized style word like i/8 / m/10 into [base-word size]; none when there is no /N suffix."
        w [word!]
        /local f p n i
    ][
        f: form w
        p: find/last f "-"
        if none? p [return none]
        n: copy skip p 1
        if empty? n [return none]
        i: attempt [to integer! n]
        if none? i [return none]
        reduce [to word! copy/part f p  i]
    ]

    family-of: func [
        "Family of a style word: sans (ss), mono (m) or serif (s), each optionally /N sized; none if not a family word."
        w [word!]
        /local ss base
    ][
        ss: size-suffix w
        base: either ss [form ss/1][form w]
        case [base = "ss" ['sans] base = "m" ['mono] base = "s" ['serif] true [none]]
    ]

    style-family: func [
        "Font family of a style block: serif (default) / sans / mono. s = serif, m = mono, ss = sans."
        styles [block!]
        /local fam
    ][
        foreach s styles [
            if word? s [fam: family-of s  if fam [return fam]]
        ]
        'serif
    ]

    width-arg?: func [
        {True for a width argument: 'auto, px/N or ch/N — as a literal issue
         (px/80) or the normalized word (px-80). Bare numbers are ambiguous and
         rejected; use px/N or ch/N.}
        a [any-type!]
        /local ss
    ][
        case [
            issue? a [true]
            a = 'auto [true]
            all [word? a  ss: size-suffix a  find [px ch] ss/1][true]
            true [false]
        ]
    ]

    box-ascent-frac: func [
        {Fraction of the measured line-box height that lies above the baseline, per
         family — the font's true ascender. `size-text` reports the whole line box,
         so both renderers split it with this to place glyphs on a common baseline.}
        styles [block!]
    ][
        case [
            (style-family styles) = 'mono [0.60]   ; Courier: asc/box
            (style-family styles) = 'sans [0.715]  ; Helvetica
            true [0.79]                            ; Times / serif
        ]
    ]

    ;=== Text metrics — single source of truth for widths and line/box heights ===
    ; Each renderer supplies a `metrics` function [text styles] -> [w h ascent]
    ; (View: OS fonts, PDF: Base-14 AFM). Lines, boxes and columns derive from it.

    line-gap-px: 1        ; vertical gap between consecutive text line boxes

    default-metrics: func [
        "Fallback metrics (no renderer): size-based estimate -> [width height ascent]"
        text [string!] styles [block!]
    ][
        reduce [
            max 1 to integer! ((length? text) * font-size * 0.583)
            max 1 to integer! (font-size * line-height-factor)
            max 1 to integer! (font-size * 0.72)
        ]
    ]

    line-ink: func [
        "Ink metrics of a line of [value styles] pairs: [height ascent descent]."
        line-block [block!] metrics [function!]
        /local best-h best-a best-d m styles text f
    ][
        best-h: 0  best-a: 0  best-d: 0
        f: get/any 'metrics
        foreach pair line-block [
            if all [block? pair (length? pair) >= 2 block? pair/2][
                styles: pair/2
                text: either string? pair/1 [pair/1][form pair/1]
                m: do reduce [f text styles]
                if m/2 > best-h [best-h: m/2]
                if m/3 > best-a [best-a: m/3]
                if (m/2 - m/3) > best-d [best-d: m/2 - m/3]
            ]
        ]
        if best-h < 1 [best-h: line-height]
        reduce [best-h best-a best-d]
    ]

    style-size: func [
        {Explicit size (from a /N suffix on a style word, e.g. i/8 / s/10 / ss/12)
         for a style block, or none. link/N / hint/N ids are not sizes.}
        styles [block!]
        /local ss
    ][
        foreach s styles [
            if word? s [
                ss: size-suffix s
                if all [ss any [find style-words ss/1  not none? family-of ss/1]][
                    return ss/2
                ]
            ]
        ]
        none
    ]

    font-size-for: func [
        "Effective font size for a style block: explicit /N size, else the style level (h*/f*), else the base size."
        styles [block!]
        /local sz
    ][
        either sz: style-size styles [sz][heading-size style-level styles]
    ]

    style-nondefault-font?: func [
        "True when a style block needs a non-default font (family, style level or explicit size)."
        styles [block!]
    ][
        not none? any [
            (style-family styles) <> 'serif
            (style-level styles) > 0
            not none? style-size styles
        ]
    ]

    line-heading: func [
        "TOC level (1-3) of a parsed line, or 0. A line is a heading when the style of its first value contains h1/h2/h3."
        line [block!]
        /local p
    ][
        if empty? line [return 0]
        p: line/1
        if all [block? p (length? p) >= 2 block? p/2][return style-heading p/2]
        0
    ]

    toc-page-token: func [
        "Private token for the page of the N-th collected heading, filled in after pagination."
        n [integer!]
    ][
        rejoin ["<toc-page-" n ">"]
    ]

    toc-heading-text: func [
        "Plain text of a collected heading line (its first value)."
        line [block!]
        /local p
    ][
        p: line/1
        either all [block? p (length? p) >= 1 string? p/1][copy p/1][form p/1]
    ]

    toc-pattern-level: func [
        "Heading level a TOC pattern line targets (from <h1>/<h2>/<h3>), or 0 if literal."
        pline [block!]
        /local lvl p
    ][
        lvl: 0
        foreach p pline [
            if all [block? p (length? p) >= 1 string? p/1][
                case [
                    find p/1 "<h1>" [lvl: 1]
                    find p/1 "<h2>" [lvl: 2]
                    find p/1 "<h3>" [lvl: 3]
                ]
            ]
        ]
        lvl
    ]

    toc-subst-line: func [
        {Clone a pattern line, substituting the heading text, page token and the
         TOC link marker (`link/toc` -> `link/toc-N`, N = heading index).}
        pline [block!] text [string!] token [string!] idx [integer!]
        /local out p sty a newsty
    ][
        out: copy/deep pline
        foreach p out [
            if all [block? p (length? p) >= 1][
                if string? p/1 [
                    p/1: replace/all p/1 "<h1>" text
                    p/1: replace/all p/1 "<h2>" text
                    p/1: replace/all p/1 "<h3>" text
                    p/1: replace/all p/1 "<t-page>" token
                ]
                if all [(length? p) >= 2 block? p/2][
                    sty: p/2  newsty: copy []
                    foreach a sty [
                        append newsty either a = 'link-toc [
                            to word! rejoin ["link-toc-" idx]
                        ][
                            a
                        ]
                    ]
                    p/2: newsty
                ]
            ]
        ]
        out
    ]

    toc-expand: func [
        {Expand a TOC item's pattern lines into concrete lines. `headings` is the
         ordered [level text] list. Entries appear in document order (page order);
         the pattern line naming a level supplies its format/indent, so a heading
         level with no pattern line is simply not listed. Literal pattern lines
         (no <hN>) are emitted first, in pattern order.}
        toc [object!] headings [block!]
        /local pats out pline lvl h idx pe have?
    ][
        ; level -> pattern line (first pattern line for a level wins)
        pats: copy []
        out: copy []
        foreach pline toc/lines [
            lvl: toc-pattern-level pline
            either lvl > 0 [
                have?: false
                foreach pe pats [if pe/1 = lvl [have?: true  break]]
                unless have? [append/only pats reduce [lvl pline]]
            ][
                append/only out copy/deep pline
            ]
        ]
        ; heading entries in document order, formatted by their level's pattern
        idx: 0
        foreach h headings [
            idx: idx + 1
            foreach pe pats [
                if pe/1 = h/1 [
                    append/only out toc-subst-line pe/2 h/2 (toc-page-token idx) idx
                    break
                ]
            ]
        ]
        out
    ]

    expand-tocs: func [
        "Collect h1/h2/h3 headings in a parsed page's BODY and replace each TOC item with its expanded lines (in place). Called by the renderers, after validation."
        page-obj [object!]
        /local headings out it hd
    ][
        headings: copy []
        foreach it page-obj/content/lines [
            if block? it [
                hd: line-heading it
                if hd > 0 [append/only headings reduce [hd (toc-heading-text it)]]
            ]
        ]
        out: copy []
        foreach it page-obj/content/lines [
            either all [object? it it/type = 'toc][
                append out toc-expand it headings
            ][
                append/only out it
            ]
        ]
        page-obj/content/lines: out
    ]

    line-advance: func [
        {Vertical slot a line occupies: its measured ink height plus the inter-line
         gap (boxes therefore just touch, separated by the gap).}
        line-block [block!] metrics [function!]
        /local lm f
    ][
        f: get/any 'metrics
        lm: line-ink line-block :f
        lm/1 + line-gap-px
    ]

    line-step: func [
        "Baseline distance from `prev` line down to `cur` line (boxes + gap touch)."
        cur [block!] prev [block! none!] metrics [function!]
        /local ci pi f
    ][
        f: get/any 'metrics
        ci: line-ink cur :f
        pi: either prev [line-ink prev :f][reduce [0 0 0]]
        pi/3 + line-gap-px + ci/2
    ]

    footer-height: func [
        "Total vertical space the footer needs (stacked line boxes plus gaps)"
        ftr [object! none!] metrics [function!]
        /local h line prev-l f lm
    ][
        h: 0
        prev-l: none
        f: get/any 'metrics
        if all [ftr ftr/lines][
            foreach line ftr/lines [
                either prev-l [
                    h: h + line-step line prev-l :f
                ][
                    lm: line-ink line :f
                    h: h + lm/2
                ]
                prev-l: line
            ]
            if prev-l [
                lm: line-ink prev-l :f
                h: h + lm/3
            ]
        ]
        h
    ]

    row-height: func [
        "Height for a table row: its measured ink height plus row padding"
        row [block!] metrics [function!]
        /local lm f
    ][
        f: get/any 'metrics
        lm: line-ink row :f
        lm/1 + row-padding
    ]

    pad-text: func [
        "Pad text to fixed width according to alignment"
        text [string!] width [integer!] align [string!]
        /local diff left-pad right-pad
    ][
        if width <= 0 [return text]
        diff: width - length? text
        if diff <= 0 [return text]
        case [
            align = "R" [
                insert/dup text " " diff
            ]
            align = "C" [
                left-pad: to integer! diff / 2
                right-pad: diff - left-pad
                insert/dup text " " left-pad
                append/dup text " " right-pad
            ]
            true [
                append/dup text " " diff
            ]
        ]
        text
    ]

    ;=== Number formatting ===

    format-number-value: function [
        "Format number with optional money/decimal/1000 format"
        val [number!] fmt [none! word! float!]
        /nopad "Do not left-pad to the integer width; the renderer's width box handles spacing"
    ][
        case [
            none? fmt [to string! val]
            fmt = 'money [
                either val < 0 [
                    rejoin ["-$" format-decimal (0 - val) 2]
                ][
                    rejoin ["$" format-decimal val 2]
                ]
            ]
            fmt = 's1000 [
                format-decimal val 0
            ]
            float? fmt [
                s: form fmt
                dpos: find s #"."
                either dpos [
                    int-width: to integer! copy/part s dpos
                    decimals: to integer! copy next dpos
                ][
                    int-width: to integer! s
                    decimals: 0
                ]
                result: format-decimal val decimals
                unless nopad [
                    if (length? result) < int-width [
                        insert/dup result " " (int-width - length? result)
                    ]
                ]
                result
            ]
            true [to string! val]
        ]
    ]

    format-decimal: function [
        "Format number with fixed decimals and thousand separators"
        val [number!] decimals [integer!]
    ][
        s: form val
        neg?: false
        if all [(length? s) > 0 s/1 = #"-"][
            neg?: true
            s: copy next s
        ]
        dpos: find s #"."
        either dpos [
            ipart: copy/part s dpos
            dec-part: copy next dpos
        ][
            ipart: copy s
            dec-part: copy ""
        ]
        if decimals > 0 [
            dpad: copy ""
            loop (decimals - length? dec-part) [append dpad "0"]
            dec-part: rejoin [dec-part dpad]
            if (length? dec-part) > decimals [dec-part: copy/part dec-part decimals]
        ]
        result: copy ""
        n: length? ipart
        i: 1
        foreach ch ipart [
            if all [i > 1 ((n - i + 1) // 3) = 0][append result "'"]
            append result ch
            i: i + 1
        ]
        either decimals > 0 [
            rejoin [either neg? ["-"][""] result "." dec-part]
        ][
            rejoin [either neg? ["-"][""] result]
        ]
    ]

    format-date-value: function [
        "Format date value as date, time, or datetime string"
        val [date!] fmt [word!]
    ][
        case [
            fmt = 'date [form val/date]
            fmt = 'time [
                t: form any [val/time 0:00]
                copy/part t ((length? t) - 3)
            ]
            true [
                d: form val/date
                t: form any [val/time 0:00]
                rejoin [d " " copy/part t ((length? t) - 3)]
            ]
        ]
    ]

    ;=== Table helpers ===

    parse-columns: function [
        "Parse column header row from pair format: [[val style?] ...]"
        pairs [block!]
    ][
        col-titles: copy []
        col-widths: copy []
        col-aligns: copy []
        col-formats: copy []
        col-bolds: copy []
        col-blanks: copy []
        num-cols: 0

        foreach pair pairs [
            val: pair/1
            styles: either all [(length? pair) >= 2 block? pair/2][pair/2][copy []]

            cur-text: case [
                string? val  [val]
                word? val    [form val]
                integer? val [form val]
                float? val   [form val]
                true         [form val]
            ]

            cur-align: "L"
            cur-bold: false
            cur-format: none
            cur-width: to integer! default-col-width * font-size * 0.5
            cur-blank: false
            foreach s styles [
                case [
                    s = '<      [cur-align: "L"]
                    s = '^      [cur-align: "C"]
                    s = '>      [cur-align: "R"]
                    s = 'b      [cur-bold: true]
                    s = 'blank  [cur-blank: true]
                    s = 'money  [cur-format: 'money]
                    s = 's1000   [cur-format: 's1000]
                    integer? s  [cur-width: to integer! s * font-size * 0.5]
                    float? s    [cur-format: s]
                    all [word? s  ss: size-suffix s  ss/1 = 'ch][cur-width: to integer! (ss/2 * font-size * 0.5)]
                    all [word? s  ss: size-suffix s  ss/1 = 'px][cur-width: ss/2]
                    issue? s    [cur-width: width-to-px s 'ch]
                ]
            ]
            append col-titles cur-text
            append col-widths cur-width
            append col-aligns cur-align
            append col-formats cur-format
            append col-bolds cur-bold
            append col-blanks cur-blank
            num-cols: num-cols + 1
        ]
        reduce [col-titles col-widths col-aligns col-formats col-bolds col-blanks num-cols]
    ]

    eval-val: func ["Resolve word to its value, or return as-is" v /local val][
        case [
            word? v     [val: attempt [get v] either not none? :val [:val][v]]
            get-word? v [val: attempt [get v] either not none? :val [:val][v]]
            true        [v]
        ]
    ]

    table-modifiers: function [
        "Scan table args for modifiers. Returns [boxed? alt?]"
        args [block!]
    ][
        boxed?: false
        alt?: false
        foreach v args [
            case [
                v = 'box [boxed?: true]
                v = 'alt [alt?: true]
            ]
        ]
        reduce [boxed? alt?]
    ]

    ; private marker used to protect escaped token-like text (\<page> etc.)
    token-escape-marker: to string! to char! 1

    token-escape: func [
        {Protect escaped token-like text: `\<page>` becomes `<` + a private marker +
         `page>`, so the token pass cannot match it. The marker is stripped by
         token-unescape after replacement. Backslash is a literal in Red strings.}
        text [string!]
    ][
        replace/all copy text "\<" rejoin ["<" token-escape-marker]
    ]

    token-unescape: func [
        "Remove the private marker left by token-escape."
        text [string!]
    ][
        replace/all copy text token-escape-marker ""
    ]

    replace-tokens: func [
        "Replace <page>, <pages> tokens (and %DATE%, %TIME%, %DATETIME%); unescape \\<…"
        text [string!] page-num [integer!] total-pages [integer!]
        date-str [string!] time-str [string!] datetime-str [string!]
    ][
        text: copy text
        text: replace/all text "<page>" to string! page-num
        text: replace/all text "<pages>" to string! total-pages
        text: replace/all text "%DATE%" date-str
        text: replace/all text "%TIME%" time-str
        text: replace/all text "%DATETIME%" datetime-str
        token-unescape text
    ]

    ;=== Layout math ===

    col-w: does [page-width - margin-left - margin-right]

    ceil-div: func ["Integer division rounding up" a [integer!] b [integer!]][
        to integer! (a + b - 1) / b
    ]

    char-est-width: func [
        "Estimated pixel width of a character at current font-size"
        ch [char!]
    ][
        case [
            find "il1|!.,;:'-_" ch [font-size * 0.3]
            find "mwMW@%&$#"    ch [font-size * 0.7]
            true                [font-size * 0.5]
        ]
    ]

    measure-column-pixels: function [
        "Measure max pixel width across all column lines (pair format)"
        col-rows [block!] img-w [issue! none!] metrics [function!]
        /local f mx ln pair val sty txt val-w ia ia-obj wd m
    ][
        f: get/any 'metrics
        mx: 0
        foreach ln col-rows [
            val-w: 0
            either block? ln [
                foreach pair ln [
                    either block? pair [
                        if (length? pair) >= 1 [
                            val: pair/1
                            sty: either all [(length? pair) >= 2 block? pair/2][pair/2][copy []]
                            txt: either any [string? val number? val date?][format-pair-value val sty][mold val]
                            ; measure what will actually be drawn: apply the same
                            ; <page>/<pages> replacement the token pass does, so a row
                            ; with literal "<page> of <pages>" is not measured longer
                            ; than its rendered "1 of 2"
                            txt: replace-tokens txt 1 1 "" "" ""
                            m: do reduce [f txt sty]
                            val-w: val-w + m/1
                        ]
                    ][
                        m: do reduce [f (form pair) copy []]
                        val-w: val-w + m/1
                    ]
                ]
            ][
                either object? ln [
                    if ln/type = 'image [
                        ia: parse-image-args ln/args
                        either img-w [
                            wd: width-to-px img-w 'px
                            val-w: wd + (2 * max 1 (to integer! (wd * 0.05)))
                        ][
                            either ia/1 [
                                val-w: width-to-px ia/1 'px
                            ][
                                ia-obj: attempt [load ia/2]
                                if image? ia-obj [val-w: ia-obj/size/x]
                            ]
                        ]
                    ]
                ][
                    if string? ln [
                        m: do reduce [f ln copy []]
                        val-w: m/1
                    ]
                ]
            ]
            if val-w > mx [mx: val-w]
        ]
        to integer! mx
    ]

    header-row-h: does [line-height + row-padding]

    ;=== Inline raw draw (BODY) — shared capability contract =================
    ; The allowlisted draw-dialect subset both renderers reproduce: the View uses
    ; Red's native draw, the PDF translates each op to vector operators. Anything
    ; outside this set is rejected so View and PDF never diverge. Coordinates are
    ; page/draw space (top-down), the same convention as DRAW-BG.

    draw-command-words: [
        pen fill-pen line-width line-join line-cap anti-alias
        box circle ellipse line triangle polygon image
    ]

    draw-load-images: func [
        {Resolve `image` arguments in a composed draw ops block for both renderers.
         The first argument may be an image!, a file! (loaded), or a word bound to
         either. Give the box as `image img pos` (natural size) or
         `image img top-left bottom-right`. Anything unresolved is skipped with a
         warning (raw DRAW-BG would otherwise crash at draw time).}
        ops [block!]
        /local out i n v x imgv p j
    ][
        out: copy []
        i: 1
        n: length? ops
        while [i <= n][
            v: ops/:i
            if all [word? v  (to word! v) = 'image][
                j: i + 1
                x: either j <= n [ops/:j][none]
                imgv: case [
                    image? x [x]
                    file? x [attempt [load x]]
                    all [word? x  image? attempt [get x]][get x]
                    all [word? x  file? attempt [get x]][attempt [load get x]]
                    true [none]
                ]
                either all [image? imgv  (j + 1) <= n  pair? ops/(j + 1)][
                    append/only out 'image
                    append/only out imgv
                    p: ops/(j + 1)
                    append/only out p
                    either all [(j + 2) <= n  pair? ops/(j + 2)][
                        append/only out ops/(j + 2)
                        i: j + 3
                    ][
                        append/only out (p + imgv/size)   ; natural size
                        i: j + 2
                    ]
                    continue
                ][
                    print "Warning: DRAW image needs an image value and a position pair; skipped"
                    i: either all [x  not draw-is-command? x][j + 1][j]
                    continue
                ]
            ]
            append/only out v
            i: i + 1
        ]
        out
    ]

    draw-command-arity: [
        pen 1  fill-pen 1  line-width 1  line-join 1  line-cap 1  anti-alias 1
        box 2  circle 2  ellipse 2  line 2  triangle 3  polygon 1  image 2
    ]

    draw-state-words: [off on round miter bevel flat square butt]

    draw-word-ok?: func [
        "A bare word in draw ops must be a state value (off/round/…), a color tuple, or an image!/file! (the IMAGE command's value)"
        w [word!]
    ][
        any [
            not none? find draw-state-words w
            tuple? attempt [get w]
            image? attempt [get w]
            file? attempt [get w]
        ]
    ]

    draw-word-problem: func [
        "First bare word in the ops that is neither a state value nor a resolvable color, or none"
        ops [block!]
        /local parsed item a
    ][
        parsed: draw-parse ops
        if all [not empty? parsed  parsed/1 = 'error][return none]
        foreach item parsed [
            foreach a item/2 [
                if word? a [
                    unless draw-word-ok? a [return a]
                ]
            ]
        ]
        none
    ]

    draw-anomaly: func [
        "First clear no-op in the draw ops (e.g. a line stroked while pen is off), or none"
        ops [block!]
        /local parsed item pen-off?
    ][
        parsed: draw-parse ops
        if all [not empty? parsed  parsed/1 = 'error][return none]
        pen-off?: false
        foreach item parsed [
            switch item/1 [
                pen  [pen-off?: all [not empty? item/2  item/2/1 = 'off]]
                line [
                    if pen-off? [
                        return "a 'line' is stroked with pen — set a pen colour (fill-pen does not affect a line)"
                    ]
                ]
            ]
        ]
        none
    ]

    draw-is-command?: func [v [any-type!]][
        all [word? v  not none? find draw-command-words to word! v]
    ]

    draw-parse: func [
        {Split a composed draw ops block into [cmd args] items. Returns a block of
         [cmd arg-block] items, or [error <token>] on the first unknown command.}
        ops [block!]
        /local pos cmd args out
    ][
        out: copy []
        pos: ops
        while [not tail? pos][
            cmd: pos/1
            unless draw-is-command? cmd [return reduce ['error cmd]]
            pos: next pos
            args: copy []
            while [all [not tail? pos  not draw-is-command? pos/1]][
                append/only args pos/1
                pos: next pos
            ]
            append/only out reduce [to word! cmd args]
        ]
        out
    ]

    draw-min-arity: func [cmd [word!] /local a][
        a: select draw-command-arity cmd
        either a [a][0]
    ]

    draw-args-ok?: func [
        "True when every command has at least its minimum number of arguments."
        ops [block!]
        /local parsed item
    ][
        parsed: draw-parse ops
        if all [not empty? parsed  parsed/1 = 'error][return false]
        foreach item parsed [
            if (length? item/2) < draw-min-arity item/1 [return false]
        ]
        true
    ]

    draw-shape-extent: func [
        "Accumulate one shape's y-extent into acc (a two-integer block [min max])."
        cmd [word!] args [block!] acc [block!]
        /local y0 y1 r v iv
    ][
        switch cmd [
            box [
                if all [(length? args) >= 2  pair? args/1  pair? args/2][
                    y0: min args/1/y args/2/y
                    y1: max args/1/y args/2/y
                    if y0 < acc/1 [acc/1: y0]
                    if y1 > acc/2 [acc/2: y1]
                ]
            ]
            circle [
                if all [(length? args) >= 2  pair? args/1  number? args/2][
                    y0: args/1/y - args/2
                    y1: args/1/y + args/2
                    if y0 < acc/1 [acc/1: y0]
                    if y1 > acc/2 [acc/2: y1]
                ]
            ]
            ellipse [
                if all [(length? args) >= 2  pair? args/1][
                    r: either pair? args/2 [args/2/y][args/2]
                    if number? r [
                        y0: args/1/y - r
                        y1: args/1/y + r
                        if y0 < acc/1 [acc/1: y0]
                        if y1 > acc/2 [acc/2: y1]
                    ]
                ]
            ]
            line [
                if all [(length? args) >= 2  pair? args/1  pair? args/2][
                    foreach v reduce [args/1 args/2][
                        if v/y < acc/1 [acc/1: v/y]
                        if v/y > acc/2 [acc/2: v/y]
                    ]
                ]
            ]
            triangle [
                if all [(length? args) >= 3  pair? args/1  pair? args/2  pair? args/3][
                    foreach v reduce [args/1 args/2 args/3][
                        if v/y < acc/1 [acc/1: v/y]
                        if v/y > acc/2 [acc/2: v/y]
                    ]
                ]
            ]
            polygon [
                foreach v args [
                    case [
                        pair? v [
                            if v/y < acc/1 [acc/1: v/y]
                            if v/y > acc/2 [acc/2: v/y]
                        ]
                        block? v [
                            if all [(length? v) >= 2 number? v/2][
                                if v/2 < acc/1 [acc/1: v/2]
                                if v/2 > acc/2 [acc/2: v/2]
                            ]
                        ]
                    ]
                ]
            ]
            image [
                if all [(length? args) >= 2  pair? args/2][
                    y0: args/2/y
                    y1: either all [(length? args) >= 3  pair? args/3][args/3/y][
                        ; natural-size form: the box height is the image's own height
                        iv: case [
                            image? args/1 [args/1]
                            file? args/1 [attempt [load args/1]]
                            all [word? args/1  image? attempt [get args/1]][get args/1]
                            all [word? args/1  file? attempt [get args/1]][attempt [load get args/1]]
                            true [none]
                        ]
                        either image? iv [args/2/y + iv/size/y][args/2/y]
                    ]
                    if y0 < acc/1 [acc/1: y0]
                    if y1 > acc/2 [acc/2: y1]
                ]
            ]
        ]
    ]

    draw-bottom-gap: 3    ; breathing room below a DRAW/FRAME auto-measured ink

    draw-ops-height: func [
        {Vertical space a composed draw ops block consumes below its placement
         cursor y (draw space), plus draw-bottom-gap. Used when DRAW omits its H.}
        ops [block!] y [integer!]
        /local parsed pen-off? width acc item cmd args h
    ][
        parsed: draw-parse ops
        if all [not empty? parsed  parsed/1 = 'error][return none]
        pen-off?: false
        width: 1
        acc: reduce [y y]
        foreach item parsed [
            cmd: item/1
            args: item/2
            switch cmd [
                pen [if not empty? args [pen-off?: args/1 = 'off]]
                line-width [if all [not empty? args  number? args/1][width: args/1]]
                box  [draw-shape-extent cmd args acc]
                circle [draw-shape-extent cmd args acc]
                ellipse [draw-shape-extent cmd args acc]
                line [draw-shape-extent cmd args acc]
                triangle [draw-shape-extent cmd args acc]
                polygon [draw-shape-extent cmd args acc]
                image [draw-shape-extent cmd args acc]
            ]
        ]
        if not pen-off? [
            acc/1: acc/1 - to integer! (width / 2)
            acc/2: acc/2 + to integer! (width / 2)
        ]
        h: max 0 to integer! (acc/2 - y)
        h + draw-bottom-gap
    ]

    ;=== Word wrap =============================================================

    style-box-width: func [
        "Pixel width of a style block's width box (px/N, ch/N, integer or float w.d), or 0 if none."
        styles [block!]
        /local w n
    ][
        w: style-width-px styles
        if w > 0 [return w]
        n: style-chars styles
        either n > 0 [to integer! (n * font-size * 0.583)][0]
    ]

    nowrap?: func [
        "True when a line's styles carry the 'nowrap' word (opt out of body wrapping)."
        line [block!]
        /local p
    ][
        foreach p line [
            if all [block? p (length? p) >= 2 block? p/2 find p/2 'nowrap][return true]
        ]
        false
    ]

    char-class: func [
        "1 = word char, 2 = space/tab, 3 = newline (hard line break)."
        c [char!]
    ][
        case [
            any [c = #"^/" c = #"^(0D)"] [3]
            any [c = #" "  c = #"^-"]     [2]
            true                          [1]
        ]
    ]

    split-keep-space: func [
        "Split a string into runs of word chars, space/tab, or newlines, preserving them."
        s [string!]
        /local out i n start cls
    ][
        out: copy []
        i: 1
        n: length? s
        while [i <= n][
            start: i
            cls: char-class s/:i
            while [all [i <= n (char-class s/:i) = cls]][i: i + 1]
            append out copy/part (at s start) (i - start)
        ]
        out
    ]

    wrap-line: func [
        {Split a text line (block of [value styles] pairs) into visual lines that fit
         within avail px. Strings break at word boundaries (indentation kept on the
         first line, long words hard-split); numbers/dates/tags and width-boxed values
         are atomic. Explicit newlines are honoured as hard breaks (blank lines kept).
         Each result is a block of pairs. `measure` is a function
         [text [string!] styles [block!]] returning the pixel width.}
        line [block!] avail [integer!] measure [function!]
        /local out cur cw push flush pair val styles box-w tok ww bw sw buf str-start?
               w chunks ch nls j k blank swidth cch cwid ti tch tw lead room pend pend-w
    ][
        out: copy []
        cur: copy []
        cw: 0
        flush: does [if not empty? cur [append/only out cur cur: copy [] cw: 0]]
        push: func [p [block!] pw [number!]][
            pw: to integer! pw
            if all [not empty? cur (cw + pw) > avail][flush]
            append/only cur p
            cw: cw + pw
        ]
        foreach pair line [
            if not all [(length? pair) >= 2 block? pair/2][continue]
            val: pair/1
            styles: pair/2
            box-w: style-box-width styles
            either string? val [
                either box-w > 0 [
                    push reduce [val styles] box-w
                ][
                    buf: copy ""
                    bw: 0
                    str-start?: true
                    sw: measure " " styles
                    foreach tok split-keep-space val [
                        case [
                            (char-class tok/1) = 3 [
                                ; explicit newlines: hard break; extra newlines keep blank lines
                                pend: none   ; spaces before a break are not visible
                                nls: 0
                                j: 1
                                while [j <= length? tok][
                                    if any [tok/:j = #"^/" (all [tok/:j = #"^(0D)" j = length? tok])][nls: nls + 1]
                                    j: j + 1
                                ]
                                if not empty? buf [
                                    push reduce [copy buf styles] bw
                                    buf: copy "" bw: 0
                                ]
                                flush
                                k: 2
                                while [k <= nls][
                                    blank: reduce [reduce [copy "" styles]]
                                    append/only out blank
                                    k: k + 1
                                ]
                                str-start?: true
                            ]
                            (char-class tok/1) = 2 [
                                ; space/tab run: kept verbatim as leading indentation, else
                                ; held as `pend` and re-inserted as a single separator before
                                ; the next word. A run at the very end of the value is
                                ; appended verbatim below, so a background color covers it.
                                either all [str-start? empty? buf][
                                    append buf tok
                                    bw: bw + measure tok styles
                                ][
                                    pend: tok
                                    pend-w: measure tok styles
                                ]
                            ]
                            true [
                                ww: measure tok styles
                                pend: none
                                lead: either str-start? [0][sw]
                                room: max 1 (avail - cw)
                                if all [(not empty? buf) ((bw + lead + ww) > room)][
                                    ; buffered words + this word do not fit: emit the buffer
                                    ; and end the line (the break replaces the space)
                                    push reduce [copy buf styles] bw
                                    buf: copy "" bw: 0
                                    flush
                                    lead: 0
                                    room: max 1 (avail - cw)
                                ]
                                if all [(not empty? cur) ((lead + ww) > room)][
                                    ; no room left on a non-empty line: start a new one
                                    flush
                                    lead: 0
                                    room: max 1 (avail - cw)
                                ]
                                if (lead + ww) > room [
                                    ; wider than a whole line: hard-split it
                                    if not empty? buf [
                                        push reduce [copy buf styles] bw
                                        buf: copy "" bw: 0
                                    ]
                                    swidth: room
                                    chunks: copy []
                                    cch: copy ""
                                    cwid: 0
                                    ti: 1
                                    while [ti <= length? tok][
                                        tch: copy/part (at tok ti) 1
                                        tw: measure tch styles
                                        if all [(not empty? cch) ((cwid + tw) > swidth)][
                                            append chunks cch
                                            cch: copy ""
                                            cwid: 0
                                        ]
                                        append cch tch
                                        cwid: cwid + tw
                                        ti: ti + 1
                                    ]
                                    if not empty? cch [append chunks cch]
                                    foreach ch chunks [
                                        unless empty? ch [push reduce [ch styles] (measure ch styles)]
                                    ]
                                    str-start?: false
                                    continue
                                ]
                                if lead > 0 [append buf " " bw: bw + lead]
                                append buf tok
                                bw: bw + ww
                                str-start?: false
                            ]
                        ]
                    ]
                    ; trailing space/tab run of the value: keep it verbatim so a
                    ; background color (2nd tuple) extends over it
                    if all [pend not empty? buf][
                        append buf pend
                        bw: bw + pend-w
                    ]
                    if not empty? buf [push reduce [copy buf styles] bw]
                ]
            ][
                w: either box-w > 0 [box-w][measure (format-pair-value val styles) styles]
                push reduce [val styles] w
            ]
        ]
        flush
        either empty? out [reduce [line]][out]
    ]

    ;=== Pair formatting helper ===

    format-pair-value: function [
        "Format a value using its style block (numbers, dates, <now> token)"
        val [any-type!] styles [block!]
    ][
        case [
            none? val   [""]
            string? val [
                ; protect escaped token-like text (\<page>, \<now>, …) first, so
                ; neither the <now> expansion below nor the token pass matches it
                val: token-escape val
                ; <now> is replaced with the current date/time, per the style block
                ; (copy: never mutate the parsed report data, it may be rendered again)
                if find val "<now>" [
                    val: replace/all copy val "<now>" (
                        case [
                            find styles 'date     [format-date-value now 'date]
                            find styles 'time     [format-date-value now 'time]
                            find styles 'datetime [format-date-value now 'datetime]
                            true                  [format-date-value now 'datetime]
                        ]
                    )
                ]
                val
            ]
            number? val [
                fmt: style-float styles
                case [
                    find styles 'money [format-number-value val 'money]
                    find styles 's1000 [format-decimal val 0]
                    fmt                [format-number-value/nopad val fmt]
                    true               [form val]
                ]
            ]
            date? val [
                case [
                    find styles 'date     [format-date-value val 'date]
                    find styles 'time     [format-date-value val 'time]
                    find styles 'datetime [format-date-value val 'datetime]
                    true                  [form val]
                ]
            ]
            ; a pure tag value: <now> -> current date/time (per the style block)
            tag? val [
                either find ["<now>"] form val [
                    case [
                        find styles 'date     [format-date-value now 'date]
                        find styles 'time     [format-date-value now 'time]
                        find styles 'datetime [format-date-value now 'datetime]
                        true                  [format-date-value now 'datetime]
                    ]
                ][
                    form val
                ]
            ]
            true [form val]
        ]
    ]

    format-pair-text: function [
        "Get display text from a value-style pair"
        pair [block!]
    ][
        val: pair/1
        styles: either all [(length? pair) >= 2 block? pair/2][pair/2][copy []]
        format-pair-value val styles
    ]

    ;=== IMAGE extras (base color, inset, shadow, caption) ===

    image-caption-info: func [
        {Parse an IMAGE caption line [value [styles]].
         Canonical form: the box clause lives in the IMAGE args (parse-image-args), so
         `styles` here is pure text styles: (b i u m s ..., h1-h3/f1-f4, size/N,
         link/N/hint/N, !X) plus the trailing 1-3 colours = caption font/background/frame.
         Legacy form (still accepted): a leading `shadow`/`border`, optional inset and box
         colour at the start of this block.
         Returns [caption color inset shadow? cap-styles link-id hint-id width]; the box
         fields are only meaningful in the legacy form.}
        line [block! none!]
        /local caption styles color inset shadow? has-box? ss cap-styles kinds text-styles colors val lid hid sid s rest pair width iss2
    ][
        caption: none
        color: none
        inset: none
        shadow?: false
        has-box?: false
        cap-styles: copy []
        lid: none
        hid: none
        width: none
        if line [
            pair: line/1
            caption: pair/1
            ; resolve colour words to tuples first: style-split only treats tuples
            ; as colours, so `blue` would otherwise stay a word and be ignored
            styles: resolve-colors either all [(length? pair) >= 2 block? pair/2][pair/2][copy []]
            rest: copy []
            ; optional width issue (px/N/ch/N): pulled out of the styles, used for sizing
            foreach s styles [
                either issue? s [
                    if none? width [width: s]
                ][
                    append rest s
                ]
            ]
            ; optional box clause: `border/N` / `shadow/N` (canonical; the /N is the
            ; inset) or the legacy `shadow|border [integer] [colour]` form.
            if all [not empty? rest  word? rest/1][
                either all [ss: size-suffix rest/1  find [shadow border] ss/1][
                    has-box?: true
                    shadow?: ss/1 = 'shadow
                    inset: ss/2
                    rest: next rest
                ][
                    if find [shadow border] rest/1 [
                        has-box?: true
                        shadow?: rest/1 = 'shadow
                        rest: next rest
                        if all [not empty? rest  integer? rest/1][
                            inset: rest/1
                            rest: next rest
                        ]
                    ]
                ]
                ; optional box colour (the first colour after the box word; default silver)
                if has-box? [
                    if all [not empty? rest  any [tuple? rest/1  all [word? rest/1  tuple? attempt [get rest/1]]]][
                        color: either tuple? rest/1 [rest/1][get rest/1]
                        rest: next rest
                    ]
                    if none? color [color: get 'silver]
                ]
            ]
            ; remaining = caption text styles + trailing caption colors
            kinds: style-split rest
            text-styles: kinds/1
            colors: kinds/2
            cap-styles: append (copy text-styles) colors
            ; extract link/hint ids from the caption styles
            foreach s text-styles [
                if word? s [
                    parse form s [
                        "link" "-" copy sid to end (lid: to-id sid)
                        | "hint" "-" copy sid to end (hid: to-id sid)
                    ]
                ]
            ]
        ]
        reduce [caption color inset shadow? cap-styles lid hid width]
    ]

    parse-image-args: func [
        {Parse an IMAGE item's args. Arguments are matched by *type*, not position:
         at most one width, one box modifier (shadow|border, optional /N inset),
         one box colour, one alignment (< ^ >), and one source (file/string/image).
         Returns [width source box-kind inset box-colour problem align]; problem is a
         message or none, align is the placement token (none = left).
         A modifier carries its optional value in a /N suffix (`border/2`, `shadow/5`),
         so a bare integer is always the image width and argument order is irrelevant.
         The caption's style block stays purely text styles/colours.}
        args [block!]
        /local w src box inset color align problem a ss
    ][
        w: none src: none box: none inset: none color: none align: none problem: none
        foreach a args [
            case [
                any [file? a string? a image? a] [
                    either src [
                        problem: "IMAGE takes one source (file, path or image)"
                    ][
                        src: either image? a [a][to file! a]
                    ]
                ]
                all [word? a  ss: size-suffix a  find [shadow border] ss/1] [
                    either box [
                        problem: "IMAGE takes at most one of shadow/border"
                    ][
                        box: ss/1  inset: ss/2
                    ]
                ]
                all [word? a  find [shadow border] a] [
                    either box [
                        problem: "IMAGE takes at most one of shadow/border"
                    ][
                        box: a
                    ]
                ]
                all [word? a  find [< ^ >] a] [
                    either align [
                        problem: "IMAGE takes at most one alignment (< ^ >)"
                    ][
                        align: a
                    ]
                ]
                all [width-arg? a  a <> 'auto] [
                    either w [
                        problem: rejoin ["IMAGE takes at most one width, got " mold w " and " mold a]
                    ][
                        w: a
                    ]
                ]
                number? a [
                    problem: rejoin ["bare width " mold a " is ambiguous; use px/N or ch/N"]
                ]
                any [tuple? a  all [word? a  tuple? attempt [get a]]] [
                    either color [
                        problem: "IMAGE takes at most one box colour"
                    ][
                        color: either tuple? a [a][get a]
                    ]
                ]
                true [
                    problem: rejoin ["unexpected argument " mold a " for IMAGE"]
                ]
            ]
            if problem [break]
        ]
        if all [none? problem  none? src][
            problem: "IMAGE needs a source: a file, a string path, or an image value"
        ]
        reduce [w src box inset color problem align]
    ]

    image-width: func [
        "Extract an optional image width issue (px/N/ch/N) from an IMAGE style block, or none."
        styles [block! none!]
        /local w s
    ][
        w: none
        if block? styles [
            foreach s styles [
                if issue? s [w: s break]
            ]
        ]
        w
    ]

    image-declared-width: func [
        {Declared width of an IMAGE line: the width argument if given (bare number = px,
         or px/N/ch/N), else a px/N/ch/N at the start of the caption style block; none = intrinsic.}
        ia [block!] cap-info [block!]
    ][
        either ia/1 [ia/1][cap-info/8]
    ]

    image-stem: func [
        "Image filename without directory or extension, as a string (Empress.jpg -> Empress)."
        f [file!]
        /local name s n i
    ][
        name: second split-path f
        s: form name
        n: 0
        i: length? s
        while [i > 0][
            if s/(i) = #"." [n: i break]
            i: i - 1
        ]
        either n > 1 [copy/part s n - 1][s]
    ]

    build-image-caption: func [
        {Build a caption line [[value [styles]]] for an IMAGE row from the row's args/lines
         and the column's image styles. Caption text default = the file's stem; '' = no caption.
         When no column image styles are given, the row's own caption style block is used.}
        row [object!] img-styles [block! none!]
        /local ia file cap styles v lst pair item-styles
    ][
        ia: parse-image-args row/args
        file: ia/2
        item-styles: copy []
        either empty? row/lines [
            ; default caption = the file's stem; an in-memory image has no name,
            ; so it gets no caption unless one is supplied
            cap: either all [file? file][image-stem file][none]
        ][
            lst: row/lines/1
            pair: lst/1
            v: pair/1
            cap: either string? v [either empty? v [none][v]][to string! v]
            if all [(length? pair) >= 2 block? pair/2][
                item-styles: pair/2
            ]
        ]
        styles: either empty? img-styles [item-styles][img-styles]
        reduce [reduce [cap styles]]
    ]

    image-row-height: func [
        {Contained height (block-h + caption-line + cap-h) of an image row for a column layout.
         width = the column's default image width (issue) if given, else the image's natural width
         contained to the column width; col-idx max-h = available page height for one row.}
        row [object!] img-styles [block! none!] col-w [integer!] max-h [integer!] col-img-w [issue! none!]
        /local ia file iobj asp ci w2 ge2 ch cap-eh
    ][
        ia: parse-image-args row/args
        file: ia/2
        if not file [return line-height]
        iobj: either image? file [file][attempt [load file]]
        if not iobj [return line-height]
        asp: to float! iobj/size/y / iobj/size/x
        ci: image-caption-info build-image-caption row img-styles
        cap-eh: either ci/1 [line-height][0]
        ; column default image width, or the natural width contained to the column cell
        w2: either col-img-w [
            width-to-px col-img-w 'px
        ][
            cw: col-w
            if iobj/size/x < cw [cw: iobj/size/x]
            ch: max 1 (max-h - line-height - cap-eh)
            if (to integer! (cw * asp)) > ch [cw: max 1 (to integer! (ch / asp))]
            cw
        ]
        ge2: image-geometry reduce [ci/2 ci/3 ci/4] (min w2 col-w) asp max-h
        ge2/9 + line-height + cap-eh
    ]

    image-geometry: func [
        {Compute IMAGE base/shadow geometry.
         ge-args = [color inset shadow?]; base-w = declared width; aspect = image h/w;
         max-h = available height (image scaled down to fit).
         Returns [img-w img-h base-w base-h base-x base-y img-x img-y block-h].}
        ge-args [block!] base-w [integer!] aspect [float!] max-h [integer!]
        /local bc binset bshadow img-w img-h bw bh bx by ix iy block-h f bs2
    ][
        bc: ge-args/1
        binset: ge-args/2
        bshadow: ge-args/3
        ; default border width = 5% of the given width when no inset is supplied
        if none? binset [binset: max 1 (to integer! (base-w * 0.05))]
        img-w: max 1 base-w
        ; box type: drop shadow (offset base), border (frame), else plain image
        case [
            bshadow [
                img-w: max 1 (base-w - binset)
                img-h: to integer! (img-w * aspect)
                bw: img-w  bh: img-h  bx: binset  by: 0 - binset  ix: 0  iy: 0
                block-h: img-h + binset
            ]
            bc [
                img-w: max 1 (base-w - (2 * binset))
                img-h: to integer! (img-w * aspect)
                bw: base-w  bh: img-h + (2 * binset)  bx: 0  by: 0  ix: binset  iy: 0 - binset
                block-h: bh
            ]
            true [
                img-h: to integer! (img-w * aspect)
                bw: base-w  bh: img-h  bx: 0  by: 0  ix: 0  iy: 0
                block-h: img-h
            ]
        ]
        if block-h > max-h [
            f: to float! max-h / block-h
            img-w: max 1 (to integer! img-w * f)
            img-h: to integer! (img-w * aspect)
            bx: to integer! bx * f  by: to integer! by * f
            ix: to integer! ix * f  iy: to integer! iy * f
            bs2: max 1 (to integer! (binset * f))
            case [
                bshadow [
                    bw: img-w  bh: img-h  block-h: img-h + bs2
                ]
                bc [
                    bw: img-w + (2 * bs2)  bh: img-h + (2 * bs2)  block-h: bh
                ]
                true [
                    bw: img-w  bh: img-h  block-h: img-h
                ]
            ]
        ]
        reduce [img-w img-h bw bh bx by ix iy block-h]
    ]

    ;=== Predefined colour shades ==========================================
    ; 0 = lightest .. 9 = darkest, one row per family (gray red pink grape
    ; violet indigo blue cyan teal green lime yellow orange). This is the
    ; runtime source of truth for the red0..red9 style colour words; the same
    ; table is mirrored by assets/color-tuples.red (generated by
    ; assets/utils/make-colors.red) for use outside the generator.
    shade-tuples: [
        gray    [248.249.250 241.243.245 233.236.239 222.226.230 206.212.218 173.181.189 134.142.150 73.80.87 52.58.64 33.37.41]
        red     [255.245.245 255.227.227 255.201.201 255.168.168 255.135.135 255.107.107 250.82.82 240.62.62 224.49.49 201.42.42]
        pink    [255.240.246 255.222.235 252.194.215 250.162.193 247.131.172 240.101.149 230.73.128 214.51.108 194.37.92 166.30.77]
        grape   [248.240.252 243.217.250 238.190.250 229.153.247 218.119.242 204.93.232 190.75.219 174.62.201 156.54.181 134.46.156]
        violet  [243.240.255 229.219.255 208.191.255 177.151.252 151.117.250 132.94.247 121.80.242 112.72.232 103.65.217 95.61.196]
        indigo  [237.242.255 219.228.255 186.200.255 145.167.255 116.143.252 92.124.250 76.110.245 66.99.235 59.91.219 54.79.199]
        blue    [231.245.255 208.235.255 165.216.255 116.192.252 77.171.247 51.154.240 34.139.230 28.126.214 25.113.194 24.100.171]
        cyan    [227.250.252 197.246.250 153.233.242 102.217.232 59.201.219 34.184.207 21.170.191 16.152.173 12.133.153 11.114.133]
        teal    [230.252.245 195.250.232 150.242.215 99.230.190 56.217.169 32.201.151 18.184.134 12.166.120 9.146.104 8.127.91]
        green   [235.251.238 211.249.216 178.242.187 140.233.154 105.219.124 81.207.102 64.192.87 55.178.77 47.158.68 43.138.62]
        lime    [244.252.227 233.250.200 216.245.162 192.235.117 169.227.75 148.216.45 130.201.30 116.184.22 102.168.15 92.148.13]
        yellow  [255.249.219 255.243.191 255.236.153 255.224.102 255.212.59 252.196.25 250.176.5 245.159.0 240.140.0 230.119.0]
        orange  [255.244.230 255.232.204 255.216.168 255.192.120 255.169.77 255.146.43 253.126.20 247.103.7 232.89.12 217.72.15]
    ]

] ; report-styles context

;=== Global colour-shade words ============================================
; Expose the shades as plain words in the global context (red0..red9,
; gray0..gray9, ...) so they can be used directly as colours in the report DSL
; and in raw DRAW/DRAW-BG/FRAME blocks, with no `do load` of an asset. Colour
; words are resolved by looking the word up (see resolve-colors), so no parser
; or renderer change is needed.
define-color-shades: function [/local fam vals i v w][
    foreach [fam vals] report-styles/shade-tuples [
        i: 0
        foreach v vals [
            w: to word! rejoin [fam i]
            set in system/words w v
            i: i + 1
        ]
    ]
]
define-color-shades
unset 'define-color-shades
