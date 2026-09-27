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
    ; big -N sizes) — lower it if large fonts get too much leading
    line-height-factor-large: 1.3
    line-height:         to integer! (font-size * line-height-factor)
    base-styles:         copy []   ; global base font styles (see make-font)
    row-padding:          4
    cell-pad:             3
    underline-offset:     2
    stroke-width:         0.5

    ;=== Unit helpers ===

    width-to-px: func [
        "Normalize a width spec to page units (px). Bare number -> default-unit ('ch or 'px). #Npx / #Nch -> explicit units."
        spec [number! issue!] default-unit [word!]
        /local s u n
    ][
        either number? spec [
            either default-unit = 'ch [
                to integer! spec * font-size * 0.5
            ][
                to integer! spec
            ]
        ][
            s: form spec
            u: copy/part skip tail s -2 2
            either find ["px" "ch"] u [
                n: to integer! copy/part s ((length? s) - 2)
                either u = "ch" [
                    to integer! n * font-size * 0.5
                ][
                    n
                ]
            ][
                print rejoin ["Warning: invalid width tag: " s]
                0
            ]
        ]
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
         link-N, colours) and a size in points. It applies to every value; per-line
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

    ; Style words are never colors; resolve-colors stops at them (colors must be last).
    style-words: [b i u s m ss h1 h2 h3 < > ^ blank money s1000 date time datetime shadow border wrap nowrap !u]

    resolve-colors: func [
        "Resolve trailing color words to tuples. Colors must be last in style block; style words are never colors."
        styles [block!]
        /local result len s val
    ][
        result: copy styles
        len: length? result
        while [len > 0][
            s: pick result len
            case [
                tuple? s [len: len - 1]
                all [word? s  not find style-words s][
                    val: attempt [get s]
                    if none? :val [break]
                    either tuple? :val [
                        poke result len val
                        len: len - 1
                    ][break]
                ]
                true [break]
            ]
        ]
        result
    ]

    ;=== Style helpers ===

    style-has: func ["Check if style block contains target word" styles [block!] target [word!]][
        not none? find styles target
    ]

    style-underline-type: func [
        "Underline style: 'solid | 'dotted | 'none.  u/link-N -> 'solid, hint-N -> 'dotted, unless !u"
        styles [block!]
        /explicit
        /local ws
    ][
        either find styles '!u [
            'none
        ][
            either find styles 'u [
                'solid
            ][
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
        ]
    ]

    style-split: func [
        "Split a style block into [directives colors]; colors = the trailing tuples/color words"
        st [block!]
        /local dir col s
    ][
        dir: copy st
        col: copy []
        while [not empty? dir][
            s: last dir
            either any [tuple? s all [word? s tuple? attempt [get s]]][
                append col first back tail dir
                remove back tail dir
            ][break]
        ]
        reduce [dir reverse col]
    ]

    merge-styles: func [
        "Merge a line (base) style with a per-value style: per-value wins on colors, alignment, family, heading, format, width; decorations (b i u ...) are additive."
        base [block!] extra [block!]
        /local bs es bd bc ed ec ov out s has-int? ndrops new-bd ed2
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
        ed2: copy []
        foreach s ed [
            unless all [word? s (length? form s) >= 2 (first form s) = #"!"][append ed2 s]
        ]
        ed: ed2
        if empty? ed [
            ; extra has no directives (only colors and/or negations): base directives
            ; plus the extra color if any, else the base color
            return append copy bd either empty? ec [bc][ec]
        ]
        ; categories extra defines, which replace the base's
        ov: copy []
        if any [find ed '< find ed '> find ed '^][append ov [< > ^]]
        if any [find ed 'm find ed 's][append ov [m s]]
        if any [find ed 'h1 find ed 'h2 find ed 'h3][append ov [h1 h2 h3]]
        if any [find ed 'money find ed 's1000 find ed 'date find ed 'time find ed 'datetime find ed 'blank][
            append ov [money s1000 date time datetime blank]
        ]
        has-int?: false
        foreach s ed [if any [integer? s issue? s][has-int?: true]]
        out: copy []
        foreach s bd [
            unless any [find ov s all [has-int? any [integer? s issue? s]]][append out s]
        ]
        foreach s ed [unless find out s [append out s]]
        append out either empty? ec [bc][ec]
        out
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
    ; A bare integer or '#Nch' on a line segment means N *average characters* in
    ; that segment's style/font: the average is measured over the alphabet below,
    ; so it is a property of the style, not of the value's text. '#Npx' is literal.
    alphabet: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

    style-width-px: func [
        "Literal pixel width from an explicit #Npx tag in styles, or 0"
        styles [block!]
        /local s u
    ][
        foreach s styles [
            if issue? s [
                u: copy/part skip tail (form s) -2 2
                if u = "px" [return to integer! copy/part form s ((length? form s) - 2)]
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
        {Character count for a width box from a bare integer, #Nch, or the width part of a
         float (w.d -> w); or 0. The fraction of a float stays the decimal count.}
        styles [block!]
        /local s u f dpos n
    ][
        foreach s styles [
            case [
                integer? s [if s > 0 [return s]]
                float? s [
                    f: form s
                    dpos: find f #"."
                    n: attempt [to integer! either dpos [copy/part f dpos][f]]
                    if all [n n > 0][return n]
                ]
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

    style-heading: func ["Return heading level (1-3) from styles, or 0" styles [block!] /local s ss b][
        foreach s styles [
            if word? s [
                ss: size-suffix s
                b: either ss [ss/1][s]
                if find [h1 h2 h3] b [return case [b = 'h1 [1] b = 'h2 [2] true [3]]]
            ]
        ]
        0
    ]

    heading-size: func [
        "Font size for heading level, scaled from the base font size (1=2x, 2=1.5x, 3=1.17x)"
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
        "Split a sized style word like i-8 / m-10 into [base-word size]; none when there is no -N suffix."
        w [word!]
        /local f p n i
    ][
        f: form w
        p: find f "-"
        if none? p [return none]
        n: copy skip p 1
        if empty? n [return none]
        i: attempt [to integer! n]
        if none? i [return none]
        reduce [to word! copy/part f p  i]
    ]

    family-of: func [
        "Family of a style word: sans (ss), mono (m) or serif (s), each optionally -N sized; none if not a family word."
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

    style-size: func [
        {Explicit size (from a -N suffix on a style word, e.g. i-8 / s-10 / ss-12)
         for a style block, or none. link-N / hint-N ids are not sizes.}
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
        "Effective font size for a style block: explicit -N size, else the heading size, else the base size."
        styles [block!]
        /local sz
    ][
        either sz: style-size styles [sz][heading-size style-heading styles]
    ]

    style-nondefault-font?: func [
        "True when a style block needs a non-default font (family, heading or explicit size)."
        styles [block!]
    ][
        not none? any [
            (style-family styles) <> 'serif
            (style-heading styles) > 0
            not none? style-size styles
        ]
    ]

    max-style-size: function [
        "Largest effective font size from style blocks in a line of pairs (0 if none)"
        line-block [block!]
    ][
        best: 0
        foreach pair line-block [
            if all [block? pair (length? pair) >= 2 block? pair/2][
                sz: font-size-for pair/2
                if sz > best [best: sz]
            ]
        ]
        either best > 0 [best][font-size]
    ]

    line-advance: func [
        {Vertical slot a line needs: spacing-factor x its largest font size.
         Above the base size the (tunable) large factor is used. Wrapped visual
         lines each get their own slot.}
        line-block [block!]
        /local sz f
    ][
        sz: max-style-size line-block
        f: either sz > font-size [line-height-factor-large][line-height-factor]
        max 1 to integer! (sz * f)
    ]

    line-gap: func [
        {Extra space before a line of size sz when the previous line's size is prev,
         so consecutive baselines follow the size-dependent spacing factor.
         Returns 0 when there is no previous line (prev = 0).}
        sz [integer!] prev [integer!]
        /local d f m
    ][
        m: max sz prev
        f: either m > font-size [line-height-factor-large][line-height-factor]
        d: to integer! ((sz - prev) * f)
        max 0 d
    ]

    footer-height: func [
        "Total vertical space the footer needs (line advances plus inter-line gaps)"
        ftr [object! none!]
        /local h line sz prev
    ][
        h: 0
        prev: 0
        if all [ftr ftr/lines][
            foreach line ftr/lines [
                sz: max-style-size line
                if prev > 0 [h: h + line-gap sz prev]
                h: h + line-advance line
                prev: sz
            ]
        ]
        h
    ]

    row-height: func [
        "Height for a table row, adapting to largest segment font"
        row [block!]
        /local sz
    ][
        sz: max-style-size row
        either sz > font-size [sz + row-padding + 1][line-height + row-padding]
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

    replace-tokens: func [
        "Replace <page>, <pages> tokens (and %DATE%, %TIME%, %DATETIME%)"
        text [string!] page-num [integer!] total-pages [integer!]
        date-str [string!] time-str [string!] datetime-str [string!]
    ][
        text: copy text
        text: replace/all text "<page>" to string! page-num
        text: replace/all text "<pages>" to string! total-pages
        text: replace/all text "%DATE%" date-str
        text: replace/all text "%TIME%" time-str
        text: replace/all text "%DATETIME%" datetime-str
        text
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
        col-rows [block!] img-w [issue! none!]
        /local mono? mx ln val-w s ch ia ia-obj wd
    ][
        mono?: false
        if all [not empty? col-rows block? col-rows/1][
            foreach pair col-rows/1 [
                if all [block? pair (length? pair) >= 2 block? pair/2][
                    foreach s pair/2 [if s = 'm [mono?: true]]
                ]
            ]
        ]
        mx: 0
        foreach ln col-rows [
            val-w: 0
            either block? ln [
                foreach pair ln [
                    val: pair/1
                    s: either any [string? val number? val date? val][form val][mold val]
                    val-w: val-w + to integer! (length? s) * (font-size * 0.583)
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
                        val-w: to integer! (length? ln) * (font-size * 0.583)
                    ]
                ]
            ]
            if val-w > mx [mx: val-w]
        ]
        to integer! mx
    ]

    header-row-h: does [line-height + row-padding]

    ;=== Word wrap =============================================================

    style-box-width: func [
        "Pixel width of a style block's width box (#Npx, #Nch, integer or float w.d), or 0 if none."
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
               w chunks ch nls j k blank swidth cch cwid ti tch tw lead room
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
                                ; space/tab: keep only as indentation at the very start
                                if all [str-start? empty? buf][
                                    append buf tok
                                    bw: bw + measure tok styles
                                ]
                            ]
                            true [
                                ww: measure tok styles
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
        {Parse an IMAGE caption line [value [styles]] with the CLI-style grammar:
         optional width issue (#Npx/#Nch), optional leading 'shadow or 'border, optional
         inset (integer), optional first color = the shadow/border color (default silver when a
         box is present and no color follows), then the caption text styles (b i u m s h1-h3,
         link-N/hint-N, !X) and the trailing 1-3 colors = the caption font/background/frame.
         Returns [caption color inset shadow? cap-styles link-id hint-id width]; 'color' is the
         box/base color for the shadow/border geometry, 'shadow?' true for a drop shadow.}
        line [block! none!]
        /local caption styles color inset shadow? cap-styles kinds text-styles colors val lid hid sid s rest pair width iss2
    ][
        caption: none
        color: none
        inset: none
        shadow?: false
        cap-styles: copy []
        lid: none
        hid: none
        width: none
        if line [
            pair: line/1
            caption: pair/1
            styles: either all [(length? pair) >= 2 block? pair/2][pair/2][copy []]
            rest: copy []
            ; optional width issue (#Npx/#Nch): pulled out of the styles, used for sizing
            foreach s styles [
                either issue? s [
                    if none? width [width: s]
                ][
                    append rest s
                ]
            ]
            ; optional box word: 'shadow (drop shadow) or 'border (frame around the image)
            if all [not empty? rest word? rest/1 find [shadow border] rest/1][
                shadow?: rest/1 = 'shadow
                rest: next rest
                ; optional inset (box width)
                if all [not empty? rest integer? rest/1][
                    inset: rest/1
                    rest: next rest
                ]
                ; optional box color (the first color is eaten; default silver)
                if all [not empty? rest any [tuple? rest/1 all [word? rest/1 tuple? attempt [get rest/1]]]][
                    color: either tuple? rest/1 [rest/1][get rest/1]
                    rest: next rest
                ]
                if none? color [color: get 'silver]
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
        "Extract [width-or-none file] from an IMAGE item's args ([width file] or [file])."
        args [block!]
        /local w f
    ][
        if empty? args [return reduce [none none]]
        either any [file? args/1 string? args/1][
            reduce [none to file! args/1]
        ][
            w: args/1
            f: either (length? args) >= 2 [to file! args/2][none]
            reduce [w f]
        ]
    ]

    image-width: func [
        "Extract an optional image width issue (#Npx/#Nch) from an IMAGE style block, or none."
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
         or #Npx/#Nch), else a #Npx/#Nch at the start of the caption style block; none = intrinsic.}
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
            cap: either file [image-stem file][""]
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
        iobj: attempt [load file]
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

] ; report-styles context
