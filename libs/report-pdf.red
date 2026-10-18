Red [
    File:      %report-pdf-generator.red
    Title:     "Report Generator (Compact)"
    Purpose:   {Generate multi-page PDF reports in pure Red
                using the compact report-parser structure.}
    Date:      2026-08-19
    Tabs:      4
    Note:      {Adapted from report-generator/report-generator.red.
                Works with parse-report structured output.
                No line-wide styles — each pair carries its own.
                PDF output is generated directly (pure Red, no Ghostscript).}
]

#include %pdf-kit.red

report-pdf: make report-styles [
    ;=== Typography (aligned with report-view for matching pagination) ===
    font-size:           12
    ; Per-family multipliers; PDF sizes may be fractional, so this is the fine
    ; parity knob against the View's whole-point serif/sans/mono sizes. These
    ; scale glyph *advances* only (width / wrapping / column measurement).
    font-scale-serif:   1.32 ;  1.1312 / 0.84
    font-scale-sans:    1.38 ;  1.125 / 0.84
    font-scale-mono:    1.4 ;  1.131 / 0.84

    ; Per-family line-box factors for the PDF's Base-14 faces, applied to the
    ; *nominal* size (base or heading) — not to the glyph-scaled size. The View
    ; measures its OS font's line box (ascender+descender at 96 dpi) for the same
    ; nominal size; these reproduce that box so lines and background boxes share
    ; one geometry across both renderers. Calibrated against the View's measured
    ; `size-text` heights (serif h2/h3 24/18/14 -> 36/28/22; mono/sans -> 17 at 12).
    line-scale-serif:   1.56
    line-scale-sans:    1.4
    line-scale-mono:    1.4

    ;=== PDF font numbers (order matches pdf-kit/font-names) ===

    bold-font:              2
    italic-font:            3
    bold-italic-font:       4
    regular-font:           1
    mono-font:              9
    mono-bold-font:         10
    mono-italic-font:       11
    mono-bold-italic-font:  12
    sans-font:              5
    sans-bold-font:         6
    sans-italic-font:       7
    sans-bold-italic-font:  8
    current-font:           1
    current-size:           font-size
    current-color:          none
    jx:                     0

    ; inline raw draw (BODY) state
    prev-draw?:             false
    prev-box:               none      ; [x y w h] draw-space box of the previous item
    track-box?:             false
    box-min-x: none  box-min-y: none  box-max-x: none  box-max-y: none

    col-apply-styles: func [
        "Merge column default styles into every value of a line (deeper per-value styles win; !X drops a column style)"
        line [block!] col-styles [block!]
        /local nl pair
    ][
        nl: copy []
        foreach pair line [
            append/only nl reduce [
                pair/1
                either block? pair/2 [merge-styles col-styles pair/2][copy col-styles]
            ]
        ]
        nl
    ]

    col-chpx: func [
        "Conservative per-character width for column layout"
        col-styles [block!]
    ][
        font-size * 0.583
    ]

    col-w-px: func [
        "Convert a COLUMN width/gap spec to px using a per-char width"
        spec [any-type!] cch [float!]
    ][
        width-spec-px spec cch
    ]

    ;=== PostScript low-level emitters ===

    emit: func [
        "Append a line of PostScript to output buffer"
        out  [string!]
        data [block!]
    ][
        append out rejoin data
        append out lf
    ]

    ps-escape: function [
        "Escape special chars for PostScript string literals"
        s [string!]
    ][
        result: copy ""
        bs: to char! 92                       ;-- backslash (ASCII 92)
        foreach ch s [
            case [
                ch = bs    [append result bs append result bs]
                ch = #"("  [append result bs append result #"("]
                ch = #")"  [append result bs append result #")"]
                true       [append result ch]
            ]
        ]
        result
    ]

    emit-font: func [
        "Set the current font for subsequent text"
        out       [string!]
        font-no   [integer!]
    ][
        current-font: font-no
    ]

    emit-text-op: func [
        "Emit PDF text (baseline at x,y); centre/right aligned within col-w"
        out [string!] x [number!] y [number!] text [string!]
        font-no [integer!] size [number!] color [tuple! none!]
        col-w-c [number! none!] col-w-r [number! none!]
        /local tw tx
    ][
        if empty? text [exit]
        tw: pdf-kit/text-width font-no size text
        tx: case [
            all [col-w-r col-w-r > 0] [x + col-w-r - tw]
            all [col-w-c col-w-c > 0] [x + ((col-w-c - tw) / 2.0)]
            true [x]
        ]
        emit out [either color [pdf-kit/rgb color] ["0 0 0"] " rg"]
        emit out [
            "BT /F" font-no " " (form size) " Tf "
            "1 0 0 1 " (pdf-kit/num tx) " " (pdf-kit/num y) " Tm <"
            (pdf-kit/hex text) "> Tj ET"
        ]
    ]

    emit-text: func [
        "Emit positioned text with optional center/right alignment"
        out [string!] x [number!] y [number!] text [string!]
        /center col-w-c [number!] /right col-w-r [number!]
    ][
        emit-text-op out x y text current-font current-size current-color
            (either col-w-c [col-w-c][0]) (either col-w-r [col-w-r][0])
    ]

    emit-text-join: func [
        "Continue left-aligned PDF text at the join cursor; advances it"
        out [string!] y [number!] text [string!]
        font-no [integer!] size [number!] color [tuple! none!]
        /local tw
    ][
        tw: pdf-kit/text-width font-no size text
        emit out [either color [pdf-kit/rgb color] ["0 0 0"] " rg"]
        emit out [
            "BT /F" font-no " " (form size) " Tf "
            "1 0 0 1 " (pdf-kit/num jx) " " (pdf-kit/num y) " Tm <"
            (pdf-kit/hex text) "> Tj ET"
        ]
        jx: jx + tw
    ]

    emit-text-start: func [
        "Initialize the join cursor at a position"
        out [string!] x [number!] y [number!]
    ][
        jx: x
    ]

    set-jx: func [
        "Set the join cursor (avoids localizing `jx` inside `function` bodies)"
        v [number!]
    ][
        jx: v
    ]

    emit-underline: func [
        "Emit underline stroke for text"
        out [string!] x [number!] y [number!] text [string!]
        col-w [number!] align [string!]
        /local tw ux
    ][
        tw: pdf-kit/text-width current-font current-size text
        ux: case [
            align = "C" [x + ((col-w - tw) / 2.0)]
            align = "R" [x + col-w - tw]
            true [x]
        ]
        emit out [
            "0 0 0 RG " stroke-width " w "
            (pdf-kit/num ux) " " (pdf-kit/num (y - underline-offset)) " m "
            (pdf-kit/num (ux + tw)) " " (pdf-kit/num (y - underline-offset)) " l S"
        ]
    ]

    emit-rect: func [
        "Emit rectangle stroke"
        out [string!] x [number!] y [number!] w [number!] h [number!]
    ][
        emit out [
            "0 0 0 RG " stroke-width " w "
            (pdf-kit/num x) " " (pdf-kit/num y) " "
            (pdf-kit/num w) " " (pdf-kit/num h) " re S"
        ]
    ]

    emit-vline: func [
        "Emit vertical line stroke"
        out [string!] x [number!] y [number!] h [number!]
    ][
        emit out [
            "0 0 0 RG " stroke-width " w "
            (pdf-kit/num x) " " (pdf-kit/num y) " m "
            (pdf-kit/num x) " " (pdf-kit/num (y + h)) " l S"
        ]
    ]

    emit-filled-rect: func [
        "Emit filled rectangle with gray level (0-1)"
        out [string!] x [number!] y [number!] w [number!] h [number!] gray [float!]
    ][
        emit out [
            (form gray) " g "
            (pdf-kit/num x) " " (pdf-kit/num y) " "
            (pdf-kit/num w) " " (pdf-kit/num h) " re f"
        ]
    ]

    ;=== Color helpers ===

    tuple-to-rgb: func [
        "Convert Red tuple (0-255) to PostScript RGB string (0.0-1.0)"
        t [tuple!]
    ][
        rejoin [
            (to float! t/1 / 255.0) " "
            (to float! t/2 / 255.0) " "
            (to float! t/3 / 255.0)
        ]
    ]

    ;=== Font selection for PostScript ===

    font-for-styles: function [
        "Select PostScript font name for style combination"
        styles [block!]
    ][
        b?: style-has styles 'b
        i?: style-has styles 'i
        fam: style-family styles
        m?: fam = 'mono
        s?: fam = 'sans
        hd: style-level styles

        either find [1 2 3] hd [
            case [
                all [m? b?] [mono-bold-font]
                m?          [mono-font]
                all [s? b?] [sans-bold-font]
                s?          [sans-font]
                b?          [bold-font]
                i?          [italic-font]
                true        [bold-font]
            ]
        ][
            case [
                all [m? b? i?] [mono-bold-italic-font]
                all [m? i?]     [mono-italic-font]
                all [m? b?]     [mono-bold-font]
                m?              [mono-font]
                all [s? b? i?] [sans-bold-italic-font]
                all [s? i?]     [sans-italic-font]
                all [s? b?]     [sans-bold-font]
                s?              [sans-font]
                all [b? i?]     [bold-italic-font]
                b?              [bold-font]
                i?              [italic-font]
                true            [regular-font]
            ]
        ]
    ]

    select-style-font: func [
        "Set the current font for given styles"
        out [string!] styles [block!]
    ][
        current-font: font-for-styles styles
    ]

    ;=== Styled text rendering ===

    pdf-underline: func [
        "Emit solid or dotted underline for a text run"
        out [string!] x0 y tw ut
        /local uyo ddx
    ][
        if ut = 'none [exit]
        uyo: pdf-kit/num (y - underline-offset)
        either ut = 'solid [
            emit out [
                "0 0 0 RG " stroke-width " w "
                (pdf-kit/num x0) " " uyo " m " (pdf-kit/num (x0 + tw)) " " uyo " l S"
            ]
        ][
            emit out ["0 0 0 RG " stroke-width " w"]
            ddx: x0
            while [ddx < (x0 + tw)][
                emit out [(pdf-kit/num ddx) " " uyo " m " (pdf-kit/num (ddx + 2)) " " uyo " l"]
                ddx: ddx + 4
            ]
            emit out ["S"]
        ]
    ]

    avg-char-width: func [
        "Average alphabet advance (px per character) for a font/size — a property of the font, not the text"
        font-no [integer!] sz [number!]
        /local tw
    ][
        tw: pdf-kit/text-width font-no sz alphabet
        tw * 1.0 / (length? alphabet)
    ]

    font-scale-for: func [
        "Per-family size multiplier for a style block (mono > sans > serif)."
        styles [block!]
        /local fam
    ][
        fam: style-family styles
        case [
            fam = 'mono [font-scale-mono]
            fam = 'sans [font-scale-sans]
            true        [font-scale-serif]
        ]
    ]

    font-line-scale-for: func [
        "Per-family line-box factor for a style block, applied to the nominal size."
        styles [block!]
        /local fam
    ][
        fam: style-family styles
        case [
            fam = 'mono [line-scale-mono]
            fam = 'sans [line-scale-sans]
            true        [line-scale-serif]
        ]
    ]

    line-measure: func [
        "Pixel width of text under a style block (for word wrap)."
        text [string!] styles [block!]
        /local any-style? fno sz
    ][
        any-style?: any [
            style-has styles 'b  style-has styles 'i  style-has styles 'u
            style-nondefault-font? styles
        ]
        fno: either any-style? [font-for-styles styles][regular-font]
        sz: (font-size-for styles) * font-scale-for styles
        pdf-kit/text-width fno sz text
    ]

    pdf-metrics: func [
        "Measure text under a style block: [width height ascent] in pts (Base-14 AFM)"
        text [string!] styles [block!]
        /local any-style? fno sz h
    ][
        any-style?: any [
            style-has styles 'b  style-has styles 'i  style-has styles 'u
            style-nondefault-font? styles
        ]
        fno: either any-style? [font-for-styles styles][regular-font]
        ; advance width uses the glyph-scaled size (matches the View's advances)
        sz: (font-size-for styles) * font-scale-for styles
        ; line box uses the *nominal* size and the family line factor, mirroring the
        ; View's measured `size-text` line height; the ascent splits that box by the
        ; family fraction (both renderers do this), so boxes/baselines line up
        h: max 1 to integer! round ((font-size-for styles) * font-line-scale-for styles)
        reduce [
            pdf-kit/text-width fno sz text
            h
            max 1 to integer! round (h * box-ascent-frac styles)
        ]
    ]

    ;=== Inline raw draw (BODY) — vector translation of the subset ==========

    kappa: 0.5523     ; circle -> cubic Bezier constant

    box-reset: does [
        box-min-x: box-min-y: box-max-x: box-max-y: none
    ]

    box-note: func [x0 [number!] y0 [number!] x1 [number!] y1 [number!]][
        x0: to integer! x0  y0: to integer! y0  x1: to integer! x1  y1: to integer! y1
        box-min-x: either box-min-x [min box-min-x x0][x0]
        box-min-y: either box-min-y [min box-min-y y0][y0]
        box-max-x: either box-max-x [max box-max-x x1][x1]
        box-max-y: either box-max-y [max box-max-y y1][y1]
    ]

    set-track-box: func ["Set the context flag (generate's function-locals would shadow it)" v [logic!]][
        track-box?: v
    ]

    draw-state-reset: does [
        prev-draw?: false
        prev-box: none
        track-box?: false
    ]

    box-finish: does [
        prev-box: either box-min-x [
            reduce [box-min-x box-min-y (box-max-x - box-min-x) (box-max-y - box-min-y)]
        ][none]
    ]

    ; Binding context for a DRAW block: page geometry plus the running cursor
    ; (x/y = top-left where the next element goes), the draw's own height (h),
    ; the content width (w) and the previous item's box (prev-*), all in
    ; page/draw space (top-down) so the ops read like ordinary draw code.
    draw-env: func [hh [integer!] cursor-y [integer!] /local e][
        e: make object! [
            page-width: 100 page-height: 100
            margin-left: 0 margin-right: 0 margin-top: 0 margin-bottom: 0
            x: 0 y: 0 w: 0 h: 0
            prev-x: 0 prev-y: 0 prev-w: 0 prev-h: 0 prev?: false
        ]
        set in e 'page-width page-width
        set in e 'page-height page-height
        set in e 'margin-left margin-left
        set in e 'margin-right margin-right
        set in e 'margin-top margin-top
        set in e 'margin-bottom margin-bottom
        set in e 'x margin-left
        set in e 'y page-height - cursor-y
        set in e 'w max 1 (page-width - margin-left - margin-right)
        set in e 'h hh
        if prev-box [
            set in e 'prev-x prev-box/1
            set in e 'prev-y prev-box/2
            set in e 'prev-w prev-box/3
            set in e 'prev-h prev-box/4
            set in e 'prev? true
        ]
        e
    ]

    ; Binding context for a FRAME's ops: the padded frame box (x/y/w/h) and the
    ; measured content box (cx/cy/cw/ch) in draw space, plus the padding.
    frame-env: func [
        fx [integer!] fy [integer!] fw [integer!] fh [integer!]
        cx [integer!] cy [integer!] cw [integer!] ch [integer!] pad [integer!]
        /local e
    ][
        e: make object! [
            page-width: 100 page-height: 100
            margin-left: 0 margin-right: 0 margin-top: 0 margin-bottom: 0
            x: 0 y: 0 w: 0 h: 0  cx: 0 cy: 0 cw: 0 ch: 0  pad: 0
        ]
        set in e 'page-width page-width
        set in e 'page-height page-height
        set in e 'margin-left margin-left
        set in e 'margin-right margin-right
        set in e 'margin-top margin-top
        set in e 'margin-bottom margin-bottom
        set in e 'x fx  set in e 'y fy  set in e 'w fw  set in e 'h fh
        set in e 'cx cx  set in e 'cy cy  set in e 'cw cw  set in e 'ch ch
        set in e 'pad pad
        e
    ]

    draw-item-height: func [
        "Height a DRAW item consumes: explicit arg, else measured from its ops."
        line [object!] cursor-y [integer!]
        /local h ops env
    ][
        either empty? line/args [
            env: draw-env 0 cursor-y
            ops: compose/deep bind copy line/lines env
            either h: draw-ops-height ops cursor-y [h][0]
        ][
            line/args/1
        ]
    ]

    draw-poly-points: func [
        "Points from polygon args: pairs as separate args, or a block of points/flat numbers."
        args [block!]
        /local pts v blk i
    ][
        pts: copy []
        foreach v args [
            case [
                pair? v [append pts v]
                block? v [
                    either all [not empty? v pair? v/1][
                        foreach p v [if pair? p [append pts p]]
                    ][
                        i: 1
                        while [i + 1 <= length? v][
                            append pts as-pair v/:i v/(i + 1)
                            i: i + 2
                        ]
                    ]
                ]
            ]
        ]
        pts
    ]

    pdf-stroke-setup: func [out [string!] st [object!]][
        either st/fill [emit out [pdf-kit/rgb st/fill " rg"]][emit out ["0 g"]]
        if st/pen [
            emit out [pdf-kit/rgb st/pen " RG " (pdf-kit/num st/width) " w " st/join " j " st/cap " J"]
        ]
    ]

    pdf-paint: func [out [string!] st [object!]][
        emit out [case [
            all [st/fill st/pen] ["B"]
            st/fill ["f"]
            st/pen ["S"]
            true ["n"]
        ]]
    ]

    pdf-emit-round-rect: func [
        out [string!] bx0 [number!] by0 [number!] bx1 [number!] by1 [number!] r [number!]
        /local kr
    ][
        kr: kappa * r
        emit out [(pdf-kit/num (bx0 + r)) " " (pdf-kit/num by0) " m"]
        emit out [(pdf-kit/num (bx1 - r)) " " (pdf-kit/num by0) " l"]
        emit out [(pdf-kit/num (bx1 - r + kr)) " " (pdf-kit/num by0) " " (pdf-kit/num bx1) " " (pdf-kit/num (by0 + r - kr)) " " (pdf-kit/num bx1) " " (pdf-kit/num (by0 + r)) " c"]
        emit out [(pdf-kit/num bx1) " " (pdf-kit/num (by1 - r)) " l"]
        emit out [(pdf-kit/num bx1) " " (pdf-kit/num (by1 - r + kr)) " " (pdf-kit/num (bx1 - r + kr)) " " (pdf-kit/num by1) " " (pdf-kit/num (bx1 - r)) " " (pdf-kit/num by1) " c"]
        emit out [(pdf-kit/num (bx0 + r)) " " (pdf-kit/num by1) " l"]
        emit out [(pdf-kit/num (bx0 + r - kr)) " " (pdf-kit/num by1) " " (pdf-kit/num bx0) " " (pdf-kit/num (by1 - r + kr)) " " (pdf-kit/num bx0) " " (pdf-kit/num (by1 - r)) " c"]
        emit out [(pdf-kit/num bx0) " " (pdf-kit/num (by0 + r)) " l"]
        emit out [(pdf-kit/num bx0) " " (pdf-kit/num (by0 + r - kr)) " " (pdf-kit/num (bx0 + r - kr)) " " (pdf-kit/num by0) " " (pdf-kit/num (bx0 + r)) " " (pdf-kit/num by0) " c"]
        emit out ["h"]
    ]

    pdf-emit-ellipse: func [
        out [string!] cx [number!] cy [number!] rx [number!] ry [number!]
        /local krx kry
    ][
        krx: kappa * rx  kry: kappa * ry
        emit out [(pdf-kit/num (cx + rx)) " " (pdf-kit/num cy) " m"]
        emit out [(pdf-kit/num (cx + rx)) " " (pdf-kit/num (cy + kry)) " " (pdf-kit/num (cx + krx)) " " (pdf-kit/num (cy + ry)) " " (pdf-kit/num cx) " " (pdf-kit/num (cy + ry)) " c"]
        emit out [(pdf-kit/num (cx - krx)) " " (pdf-kit/num (cy + ry)) " " (pdf-kit/num (cx - rx)) " " (pdf-kit/num (cy + kry)) " " (pdf-kit/num (cx - rx)) " " (pdf-kit/num cy) " c"]
        emit out [(pdf-kit/num (cx - rx)) " " (pdf-kit/num (cy - kry)) " " (pdf-kit/num (cx - krx)) " " (pdf-kit/num (cy - ry)) " " (pdf-kit/num cx) " " (pdf-kit/num (cy - ry)) " c"]
        emit out [(pdf-kit/num (cx + krx)) " " (pdf-kit/num (cy - ry)) " " (pdf-kit/num (cx + rx)) " " (pdf-kit/num (cy - kry)) " " (pdf-kit/num (cx + rx)) " " (pdf-kit/num cy) " c"]
        emit out ["h"]
    ]

    pdf-draw-color: func [
        "Resolve a draw pen/fill-pen arg to a tuple (or none): tuples pass through, color words are looked up, off -> none"
        v [any-type!]
    ][
        case [
            v = 'off     [none]
            tuple? v    [v]
            word? v     [attempt [get v]]
            true        [none]
        ]
    ]

    emit-draw-ops: function [
        "Translate composed draw ops to vector PDF operators (out appended)"
        out [string!] ops [block!]
        /local parsed st item cmd args x0 x1 y0d y1d pts pp r rx ry key imgv
    ][
        parsed: draw-parse ops
        st: make object! [fill: none pen: 0.0.0 width: 1 join: 0 cap: 0]
        foreach item parsed [
            cmd: item/1
            args: item/2
            switch cmd [
                pen [st/pen: pdf-draw-color args/1]
                fill-pen [st/fill: pdf-draw-color args/1]
                line-width [if all [not empty? args  number? args/1][st/width: args/1]]
                line-join [st/join: either args/1 = 'round [1][either args/1 = 'bevel [2][0]]]
                line-cap [st/cap: either args/1 = 'round [1][either args/1 = 'square [2][0]]]
                anti-alias []
                box [
                    if all [(length? args) >= 2  pair? args/1  pair? args/2][
                        x0: min args/1/x args/2/x
                        x1: max args/1/x args/2/x
                        y0d: min args/1/y args/2/y
                        y1d: max args/1/y args/2/y
                        pdf-stroke-setup out st
                        either all [(length? args) >= 3  number? args/3  args/3 > 0][
                            r: min args/3 (to integer! (min (x1 - x0) (y1d - y0d)) / 2)
                            pdf-emit-round-rect out x0 (page-height - y1d) x1 (page-height - y0d) r
                        ][
                            emit out [(pdf-kit/num x0) " " (pdf-kit/num (page-height - y1d)) " " (pdf-kit/num (x1 - x0)) " " (pdf-kit/num (y1d - y0d)) " re"]
                        ]
                        pdf-paint out st
                    ]
                ]
                circle [
                    if all [(length? args) >= 2  pair? args/1  number? args/2][
                        pdf-stroke-setup out st
                        pdf-emit-ellipse out args/1/x (page-height - args/1/y) args/2 args/2
                        pdf-paint out st
                    ]
                ]
                ellipse [
                    if all [(length? args) >= 2  pair? args/1][
                        rx: either pair? args/2 [args/2/x][args/2]
                        ry: either pair? args/2 [args/2/y][args/2]
                        if all [number? rx number? ry][
                            pdf-stroke-setup out st
                            pdf-emit-ellipse out args/1/x (page-height - args/1/y) rx ry
                            pdf-paint out st
                        ]
                    ]
                ]
                line [
                    if all [(length? args) >= 2  pair? args/1  pair? args/2][
                        pdf-stroke-setup out st
                        emit out [(pdf-kit/num args/1/x) " " (pdf-kit/num (page-height - args/1/y)) " m " (pdf-kit/num args/2/x) " " (pdf-kit/num (page-height - args/2/y)) " l"]
                        pdf-paint out st
                    ]
                ]
                triangle [
                    if all [(length? args) >= 3  pair? args/1  pair? args/2  pair? args/3][
                        pdf-stroke-setup out st
                        emit out [(pdf-kit/num args/1/x) " " (pdf-kit/num (page-height - args/1/y)) " m"]
                        emit out [(pdf-kit/num args/2/x) " " (pdf-kit/num (page-height - args/2/y)) " l"]
                        emit out [(pdf-kit/num args/3/x) " " (pdf-kit/num (page-height - args/3/y)) " l"]
                        emit out ["h"]
                        pdf-paint out st
                    ]
                ]
                polygon [
                    if not empty? args [
                        pts: draw-poly-points args
                        if not empty? pts [
                            pdf-stroke-setup out st
                            pp: pts/1
                            emit out [(pdf-kit/num pp/x) " " (pdf-kit/num (page-height - pp/y)) " m"]
                            foreach pp next pts [
                                emit out [(pdf-kit/num pp/x) " " (pdf-kit/num (page-height - pp/y)) " l"]
                            ]
                            emit out ["h"]
                            pdf-paint out st
                        ]
                    ]
                ]
                image [
                    ; image <image!|word bound to image!> <top-left> <bottom-right>
                    if all [(length? args) >= 3  pair? args/2  pair? args/3][
                        imgv: args/1
                        unless image? imgv [
                            if file? imgv [imgv: attempt [load imgv]]
                            if all [word? imgv  image? attempt [get imgv]][imgv: get imgv]
                            if all [word? imgv  file? attempt [get imgv]][imgv: attempt [load get imgv]]
                        ]
                        if image? imgv [
                            x0: min args/2/x args/3/x
                            x1: max args/2/x args/3/x
                            y0d: min args/2/y args/3/y
                            y1d: max args/2/y args/3/y
                            key: pdf-kit/embed-image-value imgv
                            if key [
                                emit out [
                                    "q " (pdf-kit/num (x1 - x0)) " 0 0 " (pdf-kit/num (y1d - y0d))
                                    " " (pdf-kit/num x0) " " (pdf-kit/num (page-height - y1d))
                                    " cm /" key " Do Q"
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]
    ]

    emit-draw: function [
        "Translate an inline [DRAW H [ops]] item to vector PDF operators; returns its height."
        out [string!] line [object!] cursor-y [integer!]
        /local hh ops parsed st item cmd args x0 x1 y0d y1d pts pp r rx ry
    ][
        hh: draw-item-height line cursor-y
        ops: compose/deep bind copy line/lines draw-env hh cursor-y
        emit-draw-ops out report-styles/draw-load-images ops
        hh
    ]

    emit-styled-text: function [
        "Emit text with style-aware font selection, alignment, and colors"
        out [string!] x [number!] y [number!] text [string!]
        col-w [integer!] align [string!] styles [block!]
        /join "Use cursor chaining for left-aligned segments"    ][
        if empty? text [exit]
        any-style?: any [
            style-has styles 'b
            style-has styles 'i
            style-has styles 'u
            style-nondefault-font? styles
        ]
        bg: style-bg-color styles
        if all [bg not opaque-tuple? bg][bg: none]
        fg: style-fg-color styles
        fc: style-frame-color styles
        if all [fc not opaque-tuple? fc][fc: none]
        sz: (font-size-for styles) * font-scale-for styles
        font-no: either any-style? [font-for-styles styles][regular-font]
        ut: style-underline-type/explicit styles

        ; width box: px/N is literal; a bare integer or ch/N means N average
        ; characters of this font (the alphabet average, not the value text)
        wpx: style-width-px styles
        if wpx = 0 [
            n: style-chars styles
            if n > 0 [wpx: to integer! (n * avg-char-width font-no sz)]
        ]

        mm: pdf-metrics text styles
        hh: mm/2
        ascr: mm/3
        desc: hh - ascr
        ; `y` is the line's baseline (bottom-up, like the View's internal y).
        ; The box spans the true line box around it: [y - descent, y + ascent].
        base: y
        bdesc: desc
        bh: hh

        either join [
            tw: pdf-kit/text-width font-no sz text
            jx0: jx
            tx0: case [
                all [wpx > tw align = "C"][jx0 + ((wpx - tw) / 2.0)]
                all [wpx > tw align = "R"][jx0 + wpx - tw]
                true [jx0]
            ]
            if fc [emit out [pdf-kit/rgb fc " rg " (pdf-kit/num tx0) " " (pdf-kit/num (y - bdesc)) " " (pdf-kit/num tw) " " (pdf-kit/num bh) " re f"]]
            if bg [
                either fc [
                    emit out [pdf-kit/rgb bg " rg " (pdf-kit/num (tx0 + 2)) " " (pdf-kit/num (y - bdesc + 2)) " " (pdf-kit/num (tw - 4)) " " (pdf-kit/num (bh - 4)) " re f"]
                ][
                    emit out [pdf-kit/rgb bg " rg " (pdf-kit/num tx0) " " (pdf-kit/num (y - bdesc)) " " (pdf-kit/num tw) " " (pdf-kit/num bh) " re f"]
                ]
            ]
            set-jx tx0
            emit-text-join out base text font-no sz (either fg [fg][none])
            pdf-underline out tx0 base tw ut
            if wpx > tw [set-jx jx0 + wpx]
            if track-box? [
                box-note tx0 (page-height - (y - bdesc + bh)) (tx0 + tw) (page-height - (y - bdesc))
            ]
        ][
            tw: pdf-kit/text-width font-no sz text
            ax: case [
                all [wpx > 0 align = "C"][x + ((wpx - tw) / 2.0)]
                all [wpx > 0 align = "R"][x + wpx - tw]
                align = "C" [x + ((col-w - tw) / 2.0)]
                align = "R" [x + col-w - tw]
                true [x]
            ]
            if fc [emit out [pdf-kit/rgb fc " rg " (pdf-kit/num ax) " " (pdf-kit/num (y - bdesc)) " " (pdf-kit/num tw) " " (pdf-kit/num bh) " re f"]]
            if bg [
                either fc [
                    emit out [pdf-kit/rgb bg " rg " (pdf-kit/num (ax + 2)) " " (pdf-kit/num (y - bdesc + 2)) " " (pdf-kit/num (tw - 4)) " " (pdf-kit/num (bh - 4)) " re f"]
                ][
                    emit out [pdf-kit/rgb bg " rg " (pdf-kit/num ax) " " (pdf-kit/num (y - bdesc)) " " (pdf-kit/num tw) " " (pdf-kit/num bh) " re f"]
                ]
            ]
            emit-text-op out ax base text font-no sz (either fg [fg][none]) none none
            pdf-underline out ax base tw ut
            if track-box? [
                box-note ax (page-height - (y - bdesc + bh)) (ax + tw) (page-height - (y - bdesc))
            ]
        ]
    ]
    ;=== Content/header/footer line renderers (pair format) ===

    render-pairs-line: function [
        "Render a text line (block of pairs) at position"
        out [string!] line [block!] page-y [integer!]
    ][
        if empty? line [exit]
        either 1 = length? line [
            pair: line/1
            styles: resolve-colors either all [(length? pair) >= 2 block? pair/2][pair/2][copy []]
            text: format-pair-value pair/1 styles
            emit-styled-text out margin-left page-y text col-w (style-align-for pair/1 styles) styles
        ][
            emit-text-start out margin-left page-y
            foreach pair line [
                styles: resolve-colors either all [(length? pair) >= 2 block? pair/2][pair/2][copy []]
                text: format-pair-value pair/1 styles
                emit-styled-text/join out margin-left page-y text col-w (style-align-for pair/1 styles) styles
            ]
        ]
    ]

    render-header-pairs: function [
        "Render a header/footer line with positional alignment (1st=L, 2nd=C, 3rd=R)"
        out [string!] y [integer!] line [block!]
        page-num [integer!] total-pages [integer!]
        date-str [string!] time-str [string!] datetime-str [string!]
        /default-style def-styles [block!]
    ][
        if empty? line [exit]
        repeat idx length? line [
            pair: pick line idx
            styles: resolve-colors either all [(length? pair) >= 2 block? pair/2][pair/2][copy []]
            text: format-pair-value pair/1 styles
            if number? text [text: form text]
            align: case [idx = 1 ["L"] idx = 2 ["C"] idx = 3 ["R"] true ["L"]]
            text: replace-tokens text page-num total-pages date-str time-str datetime-str
            either all [empty? styles default-style][
                emit-styled-text out margin-left y text col-w align def-styles
            ][
                emit-styled-text out margin-left y text col-w align styles
            ]
        ]
    ]

    ;=== Header / Footer rendering ===

    emit-header: function [
        {Reserve the header height at the top of a page and return the updated page-y.
         With /tokens the header is actually emitted, resolving <page>/<pages>; use
         that in assemble-pdf, once total-pages is known (emitting in the first pass
         and hex-replacing the tokens afterwards breaks right/centre alignment,
         because the x was measured from the raw token text).}
        out [string!] hdr [object! none!] page-y [integer!]
        date-str [string!] time-str [string!] datetime-str [string!]
        /tokens pn [integer!] tp [integer!]
    ][
        if none? hdr [return page-y]
        prev-l: none
        foreach line hdr/lines [
            if prev-l [page-y: page-y - line-step line prev-l :pdf-metrics]
            if tokens [
                render-header-pairs/default-style out page-y line pn tp date-str time-str datetime-str ['b]
            ]
            prev-l: line
        ]
        if tokens [emit-font out regular-font]
        page-y
    ]

    emit-footer: function [
        "Emit footer block at bottom of page"
        out [string!] ftr [object! none!] page-num [integer!] total-pages [integer!]
        date-str [string!] time-str [string!] datetime-str [string!]
    ][
        if any [none? ftr empty? ftr/lines] [exit]
        ; stack line boxes upward from margin-bottom: each baseline from its descent,
        ; then step up by the distance between consecutive baselines
        n: length? ftr/lines
        ys: copy []
        repeat k n [append ys 0]
        lm: line-ink (pick ftr/lines n) :pdf-metrics
        poke ys n (margin-bottom + lm/3)
        i: n
        while [i > 1][
            poke ys (i - 1) ((pick ys i) + line-step (pick ftr/lines i) (pick ftr/lines (i - 1)) :pdf-metrics)
            i: i - 1
        ]
        i: 0
        foreach line ftr/lines [
            i: i + 1
            render-header-pairs out (pick ys i) line page-num total-pages date-str time-str datetime-str
        ]
    ]

    ;=== Table rendering (pair format) ===

    emit-table-row: function [
        "Emit a table row (header or data)."
        out [string!] y [integer!] rh [integer!]
        tl [integer!] tw [integer!] boxed? [logic!] alt? [logic!]
        is-header [logic!] row-num [integer!]
        col-info [block!] row [block!]
    ][
        box-top: y - rh
        text-y: box-top + row-padding

        col-titles:  col-info/1
        col-widths:  col-info/2
        col-aligns:  col-info/3
        col-formats: col-info/4
        col-bolds:   col-info/5
        col-blanks:  col-info/6
        num-cols:    col-info/7

        either is-header [
            emit-filled-rect out tl box-top tw rh header-gray
        ][
            if all [alt? (row-num // 2) = 0] [
                emit-filled-rect out tl box-top tw rh alt-row-gray
            ]
        ]

        col-x: tl
        col-i: 1
        while [col-i <= num-cols][
            c-w: pick col-widths col-i
            col-align: pick col-aligns col-i
            col-format: pick col-formats col-i

            either is-header [
                col-text: pick col-titles col-i
                emit-styled-text out (col-x + cell-pad) text-y col-text (c-w - (cell-pad * 2)) col-align ['b]
            ][
                cell-styles: either col-i <= length? row [
                    pair: pick row col-i
                    resolve-colors either all [(length? pair) >= 2 block? pair/2][pair/2][copy []]
                ][copy []]

                raw-val: either col-i <= length? row [
                    pair: pick row col-i
                    pair/1
                ][none]

                final-styles: copy []
                if pick col-bolds col-i [append final-styles 'b]
                foreach s cell-styles [
                    either tuple? s [
                        append final-styles s
                    ][
                        unless any [find final-styles s  s = 'blank  s = 's1000  s = 'money] [
                            append final-styles s
                        ]
                    ]
                ]

                text: case [
                    none? raw-val   [""]
                    all [pick col-blanks col-i number? raw-val raw-val = 0] [""]
                    all [find cell-styles 'blank number? raw-val raw-val = 0] [""]
                    string? raw-val [raw-val]
                    number? raw-val [
                        either col-format [
                            format-number-value raw-val col-format
                        ][
                            cell-fmt: none
                            foreach s cell-styles [if float? s [cell-fmt: s]]
                            case [
                                find cell-styles 'money [format-number-value raw-val 'money]
                                find cell-styles 's1000 [format-decimal raw-val 0]
                                cell-fmt               [format-number-value raw-val cell-fmt]
                                true                   [form raw-val]
                            ]
                        ]
                    ]
                    date? raw-val [
                        case [
                            find cell-styles 'date     [format-date-value raw-val 'date]
                            find cell-styles 'time     [format-date-value raw-val 'time]
                            find cell-styles 'datetime [format-date-value raw-val 'datetime]
                            true                       [form raw-val]
                        ]
                    ]
                    true [form raw-val]
                ]

                cell-bg: style-bg-color final-styles
                cell-fc: style-frame-color final-styles
                if all [cell-bg not opaque-tuple? cell-bg][cell-bg: none]
                if all [cell-fc not opaque-tuple? cell-fc][cell-fc: none]
                if cell-fc [
                    append out rejoin [
                        (pdf-kit/rgb cell-fc) " rg "
                        (pdf-kit/num col-x) " " (pdf-kit/num box-top) " "
                        (pdf-kit/num c-w) " " (pdf-kit/num rh) " re f" lf
                    ]
                ]
                either cell-bg [
                    either cell-fc [
                        append out rejoin [
                            (pdf-kit/rgb cell-bg) " rg "
                            (pdf-kit/num (col-x + 2)) " " (pdf-kit/num (box-top + 2)) " "
                            (pdf-kit/num (c-w - 4)) " " (pdf-kit/num (rh - 4)) " re f" lf
                        ]
                    ][
                        append out rejoin [
                            (pdf-kit/rgb cell-bg) " rg "
                            (pdf-kit/num col-x) " " (pdf-kit/num box-top) " "
                            (pdf-kit/num c-w) " " (pdf-kit/num rh) " re f" lf
                        ]
                    ]
                ][]
                text-styles: copy []
                tuple-n: 0
                foreach s final-styles [
                    either tuple? s [
                        tuple-n: tuple-n + 1
                        if tuple-n = 1 [append text-styles s]
                    ][
                        unless float? s [append text-styles s]
                    ]
                ]
                emit-styled-text out (col-x + cell-pad) text-y text (c-w - (cell-pad * 2)) (style-align final-styles col-align) text-styles
            ]
            col-x: col-x + c-w
            col-i: col-i + 1
        ]

        if boxed? [emit-rect out tl box-top tw rh]

        col-x: tl
        col-i: 2
        while [col-i <= num-cols][
            c-w: pick col-widths (col-i - 1)
            col-x: col-x + c-w
            emit-vline out col-x box-top rh
            col-i: col-i + 1
        ]
    ]

    ;=== PDF assembly ===

    line-ascent: func [
        "Measured ascent of a parsed line block (for header top clamping)."
        line [block!]
        /local lm
    ][
        lm: line-ink line :pdf-metrics
        lm/2
    ]

    assemble-pdf: function [
        "Build PDF page objects from page buffers"
        pages [block!] total-pages [integer!]
        page-hdrs [block!] page-ftrs [block!] usable-top [integer!]
        toc-pages [block!]
        date-str [string!] time-str [string!] datetime-str [string!]
        /local pd-pages p page-ps p-h p-f hy k pg
    ][
        pd-pages: copy []
        p: 0
        while [p < total-pages][
            p: p + 1
            page-ps: copy pick pages p
            replace/all page-ps (pdf-kit/hex "<page>")   (pdf-kit/hex form p)
            replace/all page-ps (pdf-kit/hex "<pages>")  (pdf-kit/hex form total-pages)
            replace/all page-ps (pdf-kit/hex "%DATE%")   (pdf-kit/hex date-str)
            replace/all page-ps (pdf-kit/hex "%TIME%")   (pdf-kit/hex time-str)
            replace/all page-ps (pdf-kit/hex "%DATETIME%") (pdf-kit/hex datetime-str)
            k: 1
            foreach pg toc-pages [
                if pg [
                    replace/all page-ps (pdf-kit/hex (report-styles/toc-page-token k)) (pdf-kit/hex form pg)
                ]
                k: k + 1
            ]
            p-h: pick page-hdrs p
            p-f: pick page-ftrs p
            if p-h [
                hy: page-height - margin-top - (line-ascent p-h/lines/1)
                emit-header/tokens page-ps p-h hy date-str time-str datetime-str p total-pages
            ]
            if p-f [emit-footer page-ps p-f p total-pages date-str time-str datetime-str]
            append pd-pages make object! [content: page-ps]
        ]
        pdf-kit/set-paper page-width page-height
        pd-pages
    ]
    ;=== Image support ===

    img-tmp-counter: 0

    emit-image: function [
        "Emit PDF code to render an image (JPEG XObject); source = file! or image!"
        out [string!] x [number!] y [number!]
        display-w [integer!] display-h [integer!]
        src [file! image!]
        /local key
    ][
        key: either image? src [pdf-kit/embed-image-value src][pdf-kit/embed-image src]
        unless key [return false]
        append out rejoin [
            "q " display-w " 0 0 " display-h " "
            (pdf-kit/num x) " " (pdf-kit/num (y - display-h)) " cm /"
            key " Do Q" lf
        ]
        true
    ]
    emit-page-bg: function [
        "Emit PDF code placing an already-embedded image across the whole page"
        out [string!] key [word!] w [integer!] h [integer!]
    ][
        append out rejoin [
            "q " (pdf-kit/num w) " 0 0 " (pdf-kit/num h) " 0 0 cm /" key " Do Q" lf
        ]
    ]
    draw-works?: function [
        "True only when raw draw actually rasterizes (i.e. inside Red/View)"
        /local img before
    ][
        unless value? 'draw [return false]
        img: make image! reduce [4x4 black]
        before: img/1
        attempt [draw img [fill-pen 255.0.0 box 0x0 4x4]]
        img/1 <> before
    ]
    render-draw-bg: function [
        "Rasterize a raw DRAW-BG block at pixel-density into a JPEG XObject; returns key or none"
        cmds [block!] density [integer!] w [integer!] h [integer!]
        /local img base body tmp key dw dh
    ][
        ; raw draw exists only in Red/View; inside headless Red this returns none
        unless draw-works? [return none]
        body: compose/deep bind copy cmds report-pdf
        body: report-styles/draw-load-images body
        ; draw the background at page resolution, then upscale the raster to the
        ; requested density (draw's own `scale` command is unreliable here)
        base: make image! reduce [as-pair w h white]
        draw base body
        img: base
        if density > 1 [
            dw: w * density
            dh: h * density
            img: make image! reduce [as-pair dw dh white]
            draw img compose [image (base) 0x0 (as-pair dw dh)]
        ]
        tmp: to file! rejoin [what-dir %.draw-bg-.jpg]
        save/as tmp img 'jpeg
        key: pdf-kit/embed-image tmp
        if exists? tmp [delete tmp]
        key
    ]
    col-row-height: func [
        "Vertical space consumed by one column row (text line = line-height; image = the uniform img-row-h)"
        row [block! object!] col-w [integer!] col-styles [block! none!] img-row-h [integer!]
        /local
    ][
        either block? row [
            line-height
        ][
            either row/type = 'image [img-row-h][line-height]
        ]
    ]
    emit-column-image: func [
        "Emit an image row inside a column; returns the (uniform) row height consumed"
        out [string!] x [integer!] y [integer!]
        row [object!] col-w [integer!] avail [integer!] col-styles [block! none!] col-img-w [issue! none!] img-row-h [integer!]
        /local h ia wsrc img ge block-h img-cap cap-h img-w img-h bw bh bx by ix iy base-color ci cap-styles ch cw asp cap-line
    ][
        h: line-height
        ia: parse-image-args row/args
        if all [not empty? ia ia/2][
            wsrc: ia/2
            img: either image? wsrc [wsrc][attempt [load wsrc]]
            if image? img [
                ci: image-caption-info build-image-caption row col-styles
                img-cap: ci/1
                cap-styles: ci/5
                either ia/3 [
                    base-color: any [ia/5 get 'silver]
                    inset: ia/4
                    shadow?: ia/3 = 'shadow
                ][
                    base-color: ci/2
                    inset: ci/3
                    shadow?: ci/4
                ]
                cap-line: either img-cap [reduce [reduce [img-cap cap-styles]]][copy []]
                cap-h: either img-cap [line-advance cap-line :pdf-metrics][0]
                asp: to float! img/size/y / img/size/x
                ch: max 1 (img-row-h - line-height - cap-h)
                base-w: either col-img-w [width-to-px col-img-w 'px][
                    cw: col-w
                    if img/size/x < cw [cw: img/size/x]
                    if (to integer! (cw * asp)) > ch [cw: max 1 (to integer! (ch / asp))]
                    cw
                ]
                ge: image-geometry reduce [base-color inset shadow?] (min base-w col-w) asp ch
                img-w: ge/1  img-h: ge/2  bw: ge/3  bh: ge/4
                bx: ge/5  by: ge/6  ix: ge/7  iy: ge/8  block-h: ge/9
                if base-color [
                    emit out [pdf-kit/rgb base-color " rg " (pdf-kit/num (x + bx)) " " (pdf-kit/num (y + by - bh)) " " (pdf-kit/num bw) " " (pdf-kit/num bh) " re f"]
                ]
                if emit-image out (x + ix) (y + iy) img-w img-h wsrc [
                    if img-cap [emit-styled-text out x (y - block-h - cap-h) img-cap bw "C" cap-styles]
                ]
            ]
        ]
        img-row-h
    ]
    ;=== Main entry point ===

    mk-hf: func [
        "Wrap a header/footer line block as a variant object, or none when empty."
        blk [block! none!]
    ][
        either all [blk not empty? blk][object [lines: blk]][none]
    ]

    generate: function [
        "Generate a multi-page report (default A4, use paper-format to change)"
        page-obj [object!]        "Parsed page from parse-report"
        output   [file!]          "Output PDF file path"
        /browser                  "Generate PDF and open in default PDF viewer"
    ][
        ; restore this report's base font (generate resets it at the end)
        if page-obj/base-styles [
            report-pdf/base-styles: copy page-obj/base-styles
            report-pdf/font-size: page-obj/base-size
            report-pdf/line-height: page-obj/base-line-height
            report-styles/base-styles: copy page-obj/base-styles
            report-styles/font-size: page-obj/base-size
            report-styles/line-height: page-obj/base-line-height
        ]
        report-styles/expand-tocs page-obj   ; replace TOC items with their expanded lines
        hdr: page-obj/header
        ctn: page-obj/content
        ftr: page-obj/footer
        ; header/footer variants: block 2 (when present) is shown from page 2 on
        hdr1: mk-hf hdr/lines
        hdr2: either none? hdr/lines2 [hdr1][mk-hf hdr/lines2]
        ftr1: mk-hf ftr/lines
        ftr2: either none? ftr/lines2 [ftr1][mk-hf ftr/lines2]
        ; paper size/orientation comes from the page description
        paper: page-obj/paper
        either paper/2 = 'landscape [paper-format/landscape paper/1][paper-format paper/1]
        pdf-kit/images: copy []
        pdf-kit/img-tmp: 0

        set in self 'margin-left   max any [page-obj/margin/left   50] edge-pad
        set in self 'margin-right  max any [page-obj/margin/right  50] edge-pad
        set in self 'margin-top    max any [page-obj/margin/top    50] edge-pad
        set in self 'margin-bottom max any [page-obj/margin/bottom 50] edge-pad

        ; line spacing = base size x factor (per-renderer factor; the font scales
        ; already match the glyph sizes, so scaling here would double-count)
        set in self 'line-height max 1 to integer! (font-size * line-height-factor)

        ; header top clamp: the tallest variant's first line; footer band: the
        ; tallest footer (page-bottom is a fixed limit). In-body overrides count.
        hdr-ascent: 0
        blk: either hdr1 [hdr1/lines][none]
        if blk [hdr-ascent: max hdr-ascent (line-ascent blk/1)]
        blk: either hdr2 [hdr2/lines][none]
        if blk [hdr-ascent: max hdr-ascent (line-ascent blk/1)]
        ftr-band: 0
        blk: either ftr1 [ftr1/lines][none]
        if blk [ftr-band: max ftr-band footer-height object [lines: blk] :pdf-metrics]
        blk: either ftr2 [ftr2/lines][none]
        if blk [ftr-band: max ftr-band footer-height object [lines: blk] :pdf-metrics]
        foreach line ctn/lines [
            if object? line [
                case [
                    line/type = 'header [
                        if not empty? line/lines [
                            hdr-ascent: max hdr-ascent (line-ascent line/lines/1)
                        ]
                    ]
                    line/type = 'footer [
                        if not empty? line/lines [
                            ftr-band: max ftr-band footer-height object [lines: line/lines] :pdf-metrics
                        ]
                    ]
                ]
            ]
        ]

        first-line: either all [hdr1 not empty? hdr1/lines][hdr1/lines/1][
            either all [ctn not empty? ctn/lines][
                either block? ctn/lines/1 [ctn/lines/1][none]
            ][none]
        ]
        ; place the top of the first line at margin-top: reserve its measured ascent
        lm: default-metrics "Hg" copy []
        ascent: max 1 lm/3
        if first-line [
            lm: line-ink first-line :pdf-metrics
            ascent: max 1 lm/2
        ]
        if hdr-ascent > 0 [ascent: hdr-ascent]
        usable-top: page-height - margin-top - ascent
        ; reserve the full footer band (all its lines, incl. a leading empty line)
        page-bottom: margin-bottom + ftr-band

        date-str: form now/date
        time-str: copy/part form now/time ((length? form now/time) - 3)
        datetime-str: rejoin [date-str " " time-str]

        pages: copy []
        page-num: 1
        page-content: copy ""
        page-hdrs: copy []
        page-ftrs: copy []
        toc-hcount: 0
        toc-pages: copy []
        hdr-locked?: ftr-locked?: false
        hdr-pending?: ftr-pending?: false
        active-hdr: hdr1
        active-ftr: ftr1

        ; DRAW-BG: rasterize once (View only) and stamp it onto every page
        bg-key: none
        if all [object? page-obj/draw-bg not empty? page-obj/draw-bg/lines][
            bg-density: 3
            if not empty? page-obj/draw-bg/args [bg-density: page-obj/draw-bg/args/1]
            bg-density: max 1 min 8 bg-density
            bg-key: attempt [render-draw-bg page-obj/draw-bg/lines bg-density page-width page-height]
            unless bg-key [
                print "Warning: DRAW-BG ignored (raw draw is only available in Red/View)"
            ]
        ]
        if bg-key [emit-page-bg page-content bg-key page-width page-height]

        emit-font page-content regular-font

        page-y: usable-top
        prev-line: none
        prev-draw?: false
        prev-box: none
        draw-state-reset
        if active-hdr [
            page-y: page-height - margin-top - (line-ascent active-hdr/lines/1)
            page-y: emit-header page-content active-hdr page-y date-str time-str datetime-str
            prev-line: last active-hdr/lines
        ]

        new-page: does [
            append pages page-content
            append/only page-hdrs active-hdr
            append/only page-ftrs active-ftr
            page-num: page-num + 1
            unless hdr-locked? [active-hdr: either page-num = 1 [hdr1][hdr2]]
            unless ftr-locked? [active-ftr: either page-num = 1 [ftr1][ftr2]]
            if hdr-pending? [active-hdr: pending-hdr  hdr-locked?: true  hdr-pending?: false]
            if ftr-pending? [active-ftr: pending-ftr  ftr-locked?: true  ftr-pending?: false]
            page-content: copy ""
            if bg-key [emit-page-bg page-content bg-key page-width page-height]
            emit-font page-content regular-font
            page-y: usable-top
            prev-line: none
            prev-draw?: false
            prev-box: none
            if active-hdr [
                page-y: page-height - margin-top - (line-ascent active-hdr/lines/1)
                page-y: emit-header page-content active-hdr page-y date-str time-str datetime-str
                prev-line: last active-hdr/lines
            ]
        ]

        ww: max 1 (page-width - margin-left - margin-right)
        foreach line ctn/lines [
            box-reset
            ; an in-body HEADER/FOOTER stages an override for the next page onward
            if all [object? line find [header footer] line/type][
                either line/type = 'header [
                    pending-hdr: mk-hf line/lines
                    hdr-pending?: true
                ][
                    pending-ftr: mk-hf line/lines
                    ftr-pending?: true
                ]
                continue
            ]
            either object? line [
                ; step past the preceding text line box before stacking a block.
                ; DRAW draws from its top, so it hugs the previous line
                ; (descent + gap); other blocks use half the line box.
                if all [prev-line not prev-draw?] [
                    lm: line-ink prev-line :pdf-metrics
                    page-y: page-y - either line/type = 'draw [
                        lm/3 + line-gap-px
                    ][
                        lm/2 + line-gap-px
                    ]
                ]
                prev-line: none
                y0: page-y
                switch line/type [
                    table [
                        mods: table-modifiers line/args
                        boxed?: mods/1
                        alt?: mods/2

                        table-rows: line/lines
                        if empty? table-rows [continue]

                        header-row: table-rows/1
                        col-info: parse-columns header-row

                        table-left: margin-left
                        table-width: 0
                        foreach w col-info/2 [table-width: table-width + w]

                        row-h: header-row-h

                        ; start the table only if the header + first data row fit here;
                        ; otherwise the table splits (header repeats on the next page)
                        first-data: either (length? table-rows) > 1 [table-rows/2][none]
                        first-h: either all [object? first-data first-data/type = 'pagebreak][
                            row-h
                        ][
                            either first-data [row-height first-data :pdf-metrics][row-h]
                        ]
                        if (page-y - row-h - first-h - line-height) < page-bottom [new-page]

                        emit-table-row page-content page-y row-h table-left table-width boxed? alt? true 0 col-info []
                        page-y: page-y - row-h

                        row-num: 0
                        table-data: next table-rows
                        forall table-data [
                            row-item: first table-data
                            either all [object? row-item row-item/type = 'pagebreak][
                                either empty? row-item/args [
                                    new-page
                                ][
                                    if (page-y - (row-item/args/1 * line-height)) < page-bottom [new-page]
                                ]
                                row-h: header-row-h
                                emit-table-row page-content page-y row-h table-left table-width boxed? alt? true 0 col-info []
                                page-y: page-y - row-h
                            ][
                                row-h: row-height row-item :pdf-metrics
                                if (page-y - row-h) < page-bottom [
                                    new-page
                                    row-h: header-row-h
                                    emit-table-row page-content page-y row-h table-left table-width boxed? alt? true 0 col-info []
                                    page-y: page-y - row-h
                                    row-h: row-height row-item :pdf-metrics
                                ]

                                row-num: row-num + 1
                                emit-table-row page-content page-y row-h table-left table-width boxed? alt? false row-num col-info row-item
                                page-y: page-y - row-h
                            ]
                        ]
                        page-y: page-y - line-height
                    ]
                    image [
                        ia: parse-image-args line/args
                        if all [not empty? ia ia/2][
                            img-src: ia/2
                            img-obj: either image? img-src [img-src][attempt [load img-src]]
                            either img-obj [
                                cap-info: image-caption-info build-image-caption line none
                                img-cap: cap-info/1
                                cap-styles: cap-info/5
                                either ia/3 [
                                    base-color: any [ia/5 get 'silver]
                                    inset: ia/4
                                    shadow?: ia/3 = 'shadow
                                ][
                                    base-color: cap-info/2
                                    inset: cap-info/3
                                    shadow?: cap-info/4
                                ]
                                decl-w: image-declared-width ia cap-info
                                img-aspect: to float! img-obj/size/y / img-obj/size/x
                                cap-line: either img-cap [reduce [reduce [img-cap cap-styles]]][copy []]
                                cap-h: either img-cap [line-advance cap-line :pdf-metrics][0]
                                ; reserve the caption line + the line below so the whole block fits the page
                                img-avail-w: max 1 (page-width - margin-left - margin-right)
                                img-avail-full: max 1 (usable-top - page-bottom - line-height - cap-h)
                                ; no width argument: fit what is left on THIS page (put it first
                                ; for a full-page image); a declared width is contained to the page
                                img-avail-h: either decl-w [img-avail-full][max 1 (page-y - page-bottom - line-height - cap-h)]
                                img-base-w: either decl-w [width-to-px decl-w 'px][
                                    ; no width: contain the image in the available height (and width), keep aspect
                                    iw: img-obj/size/x
                                    if img-obj/size/y > img-avail-h [iw: max 1 (to integer! (img-avail-h / img-aspect))]
                                    if iw > img-avail-w [iw: img-avail-w]
                                    if (to integer! (iw * img-aspect)) > img-avail-h [iw: max 1 (to integer! (img-avail-h / img-aspect))]
                                    iw
                                ]
                                ge: image-geometry reduce [base-color inset shadow?] img-base-w img-aspect img-avail-h
                                block-h: ge/9
                                if (page-y - block-h - line-height - cap-h) < page-bottom [
                                    new-page
                                    img-avail-h: max 1 (page-y - page-bottom - line-height - cap-h)
                                    img-base-w: either decl-w [width-to-px decl-w 'px][
                                        iw: img-obj/size/x
                                        if img-obj/size/y > img-avail-h [iw: max 1 (to integer! (img-avail-h / img-aspect))]
                                        if iw > img-avail-w [iw: img-avail-w]
                                        if (to integer! (iw * img-aspect)) > img-avail-h [iw: max 1 (to integer! (img-avail-h / img-aspect))]
                                        iw
                                    ]
                                    ge: image-geometry reduce [base-color inset shadow?] img-base-w img-aspect img-avail-h
                                    block-h: ge/9
                                ]
                                img-w: ge/1  img-h: ge/2  bw: ge/3  bh: ge/4
                                bx: ge/5  by: ge/6  ix: ge/7  iy: ge/8
                                if base-color [
                                    emit page-content [pdf-kit/rgb base-color " rg "
                                        (pdf-kit/num (margin-left + bx)) " " (pdf-kit/num (page-y + by - bh)) " "
                                        (pdf-kit/num bw) " " (pdf-kit/num bh) " re f"]
                                ]
                                emit-image page-content (margin-left + ix) (page-y + iy) img-w img-h img-src
                                if img-cap [
                                    emit-styled-text page-content margin-left (page-y - block-h - cap-h) img-cap bw "C" cap-styles
                                ]
                                page-y: page-y - block-h - line-height - cap-h
                            ][
                                print rejoin ["Warning: unsupported or unreadable image: " img-src]
                            ]
                        ]
                    ]
                    column [
                        col-args: line/args
                        col-rows: line/lines

                        ; args (matched by type, order-free): one width (px/N, ch/N or
                        ; auto), one gap (gap-ch/N or gap-px/N), optional column styles
                        col-styles: copy []
                        col-img-styles: line/img
                        col-img-w: report-styles/image-width col-img-styles
                        width-spec: 'auto
                        gap-kind: none
                        gap-n: none
                        foreach a col-args [
                            case [
                                all [word? a  gs: report-styles/size-suffix a  find [gap-ch gap-px] gs/1][
                                    gap-kind: gs/1
                                    gap-n: gs/2
                                ]
                                width-arg? a [width-spec: a]
                                true [append col-styles a]
                            ]
                        ]
                        ; rows with column styles applied (for measurement + rendering)
                        styled-rows: copy []
                        either not empty? col-styles [
                            foreach c-r col-rows [append/only styled-rows either block? c-r [col-apply-styles c-r col-styles][c-r]]
                        ][
                            styled-rows: col-rows
                        ]
                        cch: col-chpx col-styles
                        either width-spec = 'auto [
                            col-col-w: measure-column-pixels styled-rows col-img-w :pdf-metrics
                        ][
                            col-col-w: col-w-px width-spec cch
                        ]
                        either gap-kind [
                            col-gap: either gap-kind = 'gap-ch [
                                to integer! (gap-n * cch)
                            ][
                                gap-n
                            ]
                        ][
                            col-gap: to integer! cch
                        ]
                        if col-gap < to integer! cch [col-gap: to integer! cch]

                        ; predetermined uniform row height for image rows = the max contained image height
                        col-img-row-h: 0
                        foreach rr col-rows [
                            if all [object? rr  rr/type = 'image] [
                                col-img-row-h: max col-img-row-h (report-styles/image-row-height rr col-img-styles col-col-w (usable-top - page-bottom) col-img-w)
                            ]
                        ]

                        col-total: length? col-rows
                        col-avail-w: page-width - margin-left - margin-right
                        either width-spec = 'auto [
                            ; `auto` width is a preference: allow a small overhang so a
                            ; near-fit still packs the extra column, then share the row
                            ; width exactly. Keeps the column count stable across the
                            ; View's and the PDF's font metrics.
                            tol: to integer! (col-col-w * 0.03)
                            col-num: to integer! ((col-avail-w + col-gap + tol) / (col-col-w + col-gap))
                            if col-num < 1 [col-num: 1]
                            if col-num > 1 [
                                fit-w: to integer! ((col-avail-w - ((col-num - 1) * col-gap)) / col-num)
                                if fit-w < col-col-w [col-col-w: fit-w]
                            ]
                        ][
                            col-num: to integer! (col-avail-w / (col-col-w + col-gap))
                            if col-num < 1 [col-num: 1]
                        ]
                        col-idx: 1
                        col-remaining: col-total
                        while [col-remaining > 0][
                            ; when a column continues onto a new page, step past
                            ; the header like other content does
                            if all [prev-line  not prev-draw?][
                                lm: line-ink prev-line :pdf-metrics
                                page-y: page-y - (lm/2 + line-gap-px)
                                prev-line: none
                            ]
                            ; start a new page if the first remaining row cannot fit
                            if (col-row-height styled-rows/:col-idx col-col-w col-img-styles col-img-row-h) > (page-y - page-bottom) [
                                if page-y < usable-top [new-page]
                            ]
                            col-avail: page-y - page-bottom

                            ; balanced rows-per-column, height-aware
                            col-rows-per-col: ceil-div col-remaining col-num
                            if col-rows-per-col < 1 [col-rows-per-col: 1]
                            while [col-rows-per-col > 1][
                                col-over?: false
                                repeat col-ci col-num [
                                    ri: col-idx + ((col-ci - 1) * col-rows-per-col)
                                    if ri > col-total [break]
                                    col-end: min (ri + col-rows-per-col) (col-total + 1)
                                    used-h: 0
                                    while [ri < col-end][
                                        used-h: used-h + col-row-height styled-rows/:ri col-col-w col-img-styles col-img-row-h
                                        if used-h > col-avail [col-over?: true]
                                        ri: ri + 1
                                    ]
                                ]
                                if not col-over? [break]
                                col-rows-per-col: col-rows-per-col - 1
                            ]
                            if col-rows-per-col < 1 [col-rows-per-col: 1]

                            col-cols-fit: col-num
                            col-rendered: 0
                            col-max-h: 0
                            repeat col-ci col-cols-fit [
                                col-x: (col-ci - 1) * (col-col-w + col-gap)
                                emit page-content ["q 1 0 0 1 " col-x " 0 cm"]
                                used-h: 0
                                ri: col-idx + ((col-ci - 1) * col-rows-per-col)
                                rr: 0
                                while [all [(rr < col-rows-per-col) ((ri + rr) <= col-total)]][
                                    row: styled-rows/(ri + rr)
                                    either block? row [
                                        render-pairs-line page-content row (page-y - used-h)
                                        used-h: used-h + line-height
                                    ][
                                        switch row/type [
                                            image [
                                                used-h: used-h + emit-column-image page-content margin-left (page-y - used-h) row col-col-w col-avail col-img-styles col-img-w col-img-row-h
                                            ]
                                            default [
                                                print ["Warning: unsupported row type in column: " row/type]
                                                used-h: used-h + line-height
                                            ]
                                        ]
                                    ]
                                    rr: rr + 1
                                ]
                                col-max-h: max col-max-h used-h
                                emit page-content ["Q"]
                            ]
                            col-rendered: min (col-rows-per-col * col-cols-fit) col-remaining
                            col-idx: col-idx + col-rendered
                            col-remaining: col-remaining - col-rendered
                            page-y: page-y - col-max-h
                            if col-remaining > 0 [new-page]
                        ]
                    ]
                    pagebreak [
                        either empty? line/args [
                            new-page
                        ][
                            if (page-y - (line/args/1 * line-height)) < page-bottom [new-page]
                        ]
                    ]
                    draw [
                        dh: draw-item-height line page-y
                        ; start a new page if the draw does not fit here
                        if (dh > (page-y - page-bottom)) [new-page]
                        y0: page-y
                        emit-draw page-content line y0
                        page-y: page-y - dh
                    ]
                    frame [
                        ; v1: text-line items. Render them, measure, then splice the
                        ; backdrop into the stream in front of them. No internal page
                        ; break: if the whole frame does not fit it moves to a new page.
                        frm-mark: length? page-content
                        frm-y0: page-y
                        box-reset
                        set-track-box true
                        foreach fitm line/lines [
                            lines: wrap-line fitm (either nowrap? fitm [1000000][col-w]) :line-measure
                            foreach l lines [
                                if prev-line [page-y: page-y - line-step l prev-line :pdf-metrics]
                                render-pairs-line page-content l page-y
                                prev-line: l
                            ]
                        ]
                        ; overflowed and not already at the page top: redo on a fresh page
                        if all [(page-y < page-bottom) (frm-y0 < usable-top)] [
                            clear at page-content (frm-mark + 1)
                            new-page
                            frm-mark: length? page-content
                            frm-y0: page-y
                            box-reset
                            prev-line: none
                            foreach fitm line/lines [
                                lines: wrap-line fitm (either nowrap? fitm [1000000][col-w]) :line-measure
                                foreach l lines [
                                    if prev-line [page-y: page-y - line-step l prev-line :pdf-metrics]
                                    render-pairs-line page-content l page-y
                                    prev-line: l
                                ]
                            ]
                        ]
                        set-track-box false
                        either box-min-x [
                            fcx: box-min-x  fcy: box-min-y
                            fcw: box-max-x - box-min-x  fch: box-max-y - box-min-y
                        ][
                            fcx: margin-left  fcw: ww  fcy: page-height - frm-y0  fch: frm-y0 - page-y
                        ]
                        fpad: either empty? line/args [0][line/args/1]
                        env: frame-env (fcx - fpad) (fcy - fpad) (fcw + (2 * fpad)) (fch + (2 * fpad)) fcx fcy fcw fch fpad
                        fops: copy ""
                        emit-draw-ops fops report-styles/draw-load-images compose/deep bind copy line/ops env
                        insert at page-content (frm-mark + 1) fops
                        box-finish
                        prev-box: reduce [fcx - fpad  fcy - fpad  fcw + (2 * fpad)  fch + (2 * fpad)]
                        prev-draw?: true
                        prev-line: copy []
                    ]
                ]
                ; a PAGEBREAK already started a new page and set prev-line to the
                ; last header line; keep it so the next text steps below the header
                unless any [line/type = 'frame  line/type = 'pagebreak][
                    prev-draw?: line/type = 'draw
                    ; record the item's box for a following DRAW's prev-* words
                    box-note margin-left (page-height - y0) (margin-left + ww) (page-height - page-y)
                    ; after a DRAW leave a zero-descent marker so the next text line
                    ; steps below the art (a following block skips the step)
                    either prev-draw? [prev-line: copy []][prev-line: none]
                ]
            ][
                if block? line [
                    set-track-box true
                    lines: wrap-line line (either nowrap? line [1000000][col-w]) :line-measure
                    wi: 0
                    foreach l lines [
                        wi: wi + 1
                        if prev-line [page-y: page-y - line-step l prev-line :pdf-metrics]
                        lm: line-ink l :pdf-metrics
                        if (page-y - lm/3) < page-bottom [
                            new-page
                            if prev-line [page-y: page-y - line-step l prev-line :pdf-metrics]
                        ]
                        if all [wi = 1 (report-styles/line-heading line) > 0][
                            toc-hcount: toc-hcount + 1
                            append toc-pages page-num
                        ]
                        render-pairs-line page-content l page-y
                        prev-line: l
                    ]
                    set-track-box false
                    prev-draw?: false
                ]
            ]
            unless all [object? line  line/type = 'frame][box-finish]
        ]

        append pages page-content
        append/only page-hdrs active-hdr
        append/only page-ftrs active-ftr
        total-pages: length? pages

        pd-pages: assemble-pdf pages total-pages page-hdrs page-ftrs usable-top toc-pages date-str time-str datetime-str
        pdf-kit/save-pdf output pd-pages
        if browser [browse output]
        reset-font
    ]
]; report-pdf

;=== Export ===

;generate: :report-pdf/generate