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
    ; parity knob against the View's whole-point serif/sans/mono sizes.
    font-scale-serif:   1.32 ;  1.1312 / 0.84
    font-scale-sans:    1.38 ;  1.125 / 0.84
    font-scale-mono:    1.4 ;  1.131 / 0.84

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
        spec [number! issue!] cch [float!]
        /local s u n
    ][
        either number? spec [
            to integer! spec * cch
        ][
            s: form spec
            u: copy/part skip tail s -2 2
            either find ["px" "ch"] u [
                n: to integer! copy/part s ((length? s) - 2)
                either u = "ch" [to integer! n * cch][n]
            ][
                print rejoin ["Warning: invalid width tag: " s]
                0
            ]
        ]
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
        m?: style-has styles 'm
        s?: style-has styles 's
        hd: style-heading styles

        either hd > 0 [
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
    ][
        case [
            style-has styles 'm [font-scale-mono]
            style-has styles 's [font-scale-sans]
            true               [font-scale-serif]
        ]
    ]

    line-measure: func [
        "Pixel width of text under a style block (for word wrap)."
        text [string!] styles [block!]
        /local any-style? fno sz
    ][
        any-style?: any [
            style-has styles 'b  style-has styles 'i  style-has styles 'u
            style-has styles 'm  style-has styles 's  (style-heading styles) > 0
        ]
        fno: either any-style? [font-for-styles styles][regular-font]
        sz: (heading-size style-heading styles) * font-scale-for styles
        pdf-kit/text-width fno sz text
    ]

    emit-styled-text: function [
        "Emit text with style-aware font selection, alignment, and colors"
        out [string!] x [number!] y [number!] text [string!]
        col-w [integer!] align [string!] styles [block!]
        /join "Use cursor chaining for left-aligned segments"
    ][
        if empty? text [exit]
        any-style?: any [
            style-has styles 'b
            style-has styles 'i
            style-has styles 'u
            style-has styles 'm
            style-has styles 's
            (style-heading styles) > 0
        ]
        bg: style-bg-color styles
        fg: style-fg-color styles
        fc: style-frame-color styles
        sz: heading-size style-heading styles
        sz: sz * font-scale-for styles
        font-no: either any-style? [font-for-styles styles][regular-font]
        ut: style-underline-type/explicit styles

        ; width box: #Npx is literal; a bare integer or #Nch means N average
        ; characters of this font (the alphabet average, not the value text)
        wpx: style-width-px styles
        if wpx = 0 [
            n: style-chars styles
            if n > 0 [wpx: to integer! (n * avg-char-width font-no sz)]
        ]

        either join [
            tw: pdf-kit/text-width font-no sz text
            jx0: jx
            tx0: case [
                all [wpx > tw align = "C"][jx0 + ((wpx - tw) / 2.0)]
                all [wpx > tw align = "R"][jx0 + wpx - tw]
                true [jx0]
            ]
            if fc [emit out [pdf-kit/rgb fc " rg " (pdf-kit/num tx0) " " (pdf-kit/num (y - 5)) " " (pdf-kit/num tw) " " (pdf-kit/num (sz + 4)) " re f"]]
            if bg [
                either fc [
                    emit out [pdf-kit/rgb bg " rg " (pdf-kit/num (tx0 + 2)) " " (pdf-kit/num (y - 3)) " " (pdf-kit/num (tw - 4)) " " (pdf-kit/num sz) " re f"]
                ][
                    emit out [pdf-kit/rgb bg " rg " (pdf-kit/num tx0) " " (pdf-kit/num (y - 5)) " " (pdf-kit/num tw) " " (pdf-kit/num (sz + 4)) " re f"]
                ]
            ]
            set-jx tx0
            emit-text-join out y text font-no sz (either fg [fg][none])
            pdf-underline out tx0 y tw ut
            if wpx > tw [set-jx jx0 + wpx]
        ][
            tw: pdf-kit/text-width font-no sz text
            ax: case [
                all [wpx > 0 align = "C"][x + ((wpx - tw) / 2.0)]
                all [wpx > 0 align = "R"][x + wpx - tw]
                align = "C" [x + ((col-w - tw) / 2.0)]
                align = "R" [x + col-w - tw]
                true [x]
            ]
            if fc [emit out [pdf-kit/rgb fc " rg " (pdf-kit/num ax) " " (pdf-kit/num (y - 5)) " " (pdf-kit/num tw) " " (pdf-kit/num (sz + 4)) " re f"]]
            if bg [
                either fc [
                    emit out [pdf-kit/rgb bg " rg " (pdf-kit/num (ax + 2)) " " (pdf-kit/num (y - 3)) " " (pdf-kit/num (tw - 4)) " " (pdf-kit/num sz) " re f"]
                ][
                    emit out [pdf-kit/rgb bg " rg " (pdf-kit/num ax) " " (pdf-kit/num (y - 5)) " " (pdf-kit/num tw) " " (pdf-kit/num (sz + 4)) " re f"]
                ]
            ]
            emit-text-op out ax y text font-no sz (either fg [fg][none]) none none
            pdf-underline out ax y tw ut
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
        foreach line hdr/lines [
            if tokens [
                render-header-pairs/default-style out page-y line pn tp date-str time-str datetime-str ['b]
            ]
            page-y: page-y - line-advance line
        ]
        if tokens [emit-font out regular-font]
        page-y
    ]

    emit-footer: function [
        "Emit footer block at bottom of page"
        out [string!] ftr [object! none!] page-num [integer!] total-pages [integer!]
        date-str [string!] time-str [string!] datetime-str [string!]
    ][
        if none? ftr [exit]
        ; lines stack upward from margin-bottom; a heading line takes its own slot
        h: 0
        foreach line ftr/lines [h: h + line-advance line]
        ftr-y: margin-bottom + h
        foreach line ftr/lines [
            ftr-y: ftr-y - line-advance line
            render-header-pairs out ftr-y line page-num total-pages date-str time-str datetime-str
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

    assemble-pdf: function [
        "Build PDF page objects from page buffers"
        pages [block!] total-pages [integer!]
        hdr [object! none!] ftr [object! none!] usable-top [integer!]
        date-str [string!] time-str [string!] datetime-str [string!]
        /local pd-pages p page-ps
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
            emit-header/tokens page-ps hdr usable-top date-str time-str datetime-str p total-pages
            emit-footer page-ps ftr p total-pages date-str time-str datetime-str
            append pd-pages make object! [content: page-ps]
        ]
        pdf-kit/set-paper page-width page-height
        pd-pages
    ]
    ;=== Image support ===

    img-tmp-counter: 0

    emit-image: function [
        "Emit PDF code to render an image (JPEG XObject)"
        out [string!] x [number!] y [number!]
        display-w [integer!] display-h [integer!]
        file [file!]
        /local key
    ][
        key: pdf-kit/embed-image file
        unless key [return false]
        append out rejoin [
            "q " display-w " 0 0 " display-h " "
            (pdf-kit/num x) " " (pdf-kit/num (y - display-h)) " cm /"
            key " Do Q" lf
        ]
        true
    ]
    col-row-height: func [
        "Vertical space consumed by one column row (text line = line-height; image = uniform img-row-h)"
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
        /local h ia wfile img ge block-h img-cap cap-h img-w img-h bw bh bx by ix iy base-color ci cap-styles ch cw asp
    ][
        h: line-height
        ia: parse-image-args row/args
        if all [not empty? ia ia/2][
            wfile: ia/2
            img: attempt [load wfile]
            if image? img [
                ci: image-caption-info build-image-caption row col-styles
                base-color: ci/2
                img-cap: ci/1
                cap-styles: ci/5
                cap-h: either img-cap [line-height][0]
                asp: to float! img/size/y / img/size/x
                ch: max 1 (img-row-h - line-height - cap-h)
                base-w: either col-img-w [width-to-px col-img-w 'px][
                    cw: col-w
                    if img/size/x < cw [cw: img/size/x]
                    if (to integer! (cw * asp)) > ch [cw: max 1 (to integer! (ch / asp))]
                    cw
                ]
                ge: image-geometry reduce [base-color ci/3 ci/4] (min base-w col-w) asp ch
                img-w: ge/1  img-h: ge/2  bw: ge/3  bh: ge/4
                bx: ge/5  by: ge/6  ix: ge/7  iy: ge/8  block-h: ge/9
                if base-color [
                    emit out [pdf-kit/rgb base-color " rg " (pdf-kit/num (x + bx)) " " (pdf-kit/num (y + by - bh)) " " (pdf-kit/num bw) " " (pdf-kit/num bh) " re f"]
                ]
                if emit-image out (x + ix) (y + iy) img-w img-h wfile [
                    if img-cap [emit-styled-text out x (y - block-h - line-height) img-cap bw "C" cap-styles]
                ]
            ]
        ]
        img-row-h
    ]
    ;=== Main entry point ===

    generate: function [
        "Generate a multi-page report (default A4, use paper-format to change)"
        page-obj [object!]        "Parsed page from parse-report"
        output   [file!]          "Output PDF file path"
        /browser                  "Generate PDF and open in default PDF viewer"
    ][
        hdr: page-obj/header
        ctn: page-obj/content
        ftr: page-obj/footer
        ; paper size/orientation comes from the page description
        paper: page-obj/paper
        either paper/2 = 'landscape [paper-format/landscape paper/1][paper-format paper/1]
        pdf-kit/images: copy []
        pdf-kit/img-tmp: 0

        set in self 'margin-left   max any [page-obj/margin/left   50] edge-pad
        set in self 'margin-right  max any [page-obj/margin/right  50] edge-pad
        set in self 'margin-top    max any [page-obj/margin/top    50] edge-pad
        set in self 'margin-bottom max any [page-obj/margin/bottom 50] edge-pad

        first-line: either all [hdr not empty? hdr/lines][hdr/lines/1][
            either all [ctn not empty? ctn/lines][
                either block? ctn/lines/1 [ctn/lines/1][none]
            ][none]
        ]
        ; place the top of the first line at margin-top: reserve its glyph ascent
        ascent: to integer! (font-size * 0.72)
        if first-line [
            first-sz: max-style-size first-line
            first-styles: either all [block? first-line not empty? first-line block? first-line/1/2][first-line/1/2][copy []]
            first-scale: font-scale-for first-styles
            ascent: to integer! (first-sz * first-scale * 0.72)
        ]
        usable-top: page-height - margin-top - (max 1 ascent)
        ; reserve the full footer (all its lines, incl. a leading empty line)
        page-bottom: margin-bottom + footer-height ftr

        date-str: form now/date
        time-str: copy/part form now/time ((length? form now/time) - 3)
        datetime-str: rejoin [date-str " " time-str]

        pages: copy []
        page-num: 1
        page-content: copy ""

        emit-font page-content regular-font

        page-y: usable-top
        page-y: emit-header page-content hdr page-y date-str time-str datetime-str

        new-page: does [
            append pages page-content
            page-num: page-num + 1
            page-content: copy ""
            emit-font page-content regular-font
            page-y: usable-top
            page-y: emit-header page-content hdr page-y date-str time-str datetime-str
        ]

        foreach line ctn/lines [
            either object? line [
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
                            either first-data [row-height first-data][row-h]
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
                                row-h: row-height row-item
                                if (page-y - row-h) < page-bottom [
                                    new-page
                                    row-h: header-row-h
                                    emit-table-row page-content page-y row-h table-left table-width boxed? alt? true 0 col-info []
                                    page-y: page-y - row-h
                                    row-h: row-height row-item
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
                            img-file: ia/2
                            img-obj: attempt [load img-file]
                            either img-obj [
                                cap-info: image-caption-info build-image-caption line none
                                base-color: cap-info/2
                                img-cap: cap-info/1
                                cap-styles: cap-info/5
                                decl-w: image-declared-width ia cap-info
                                img-aspect: to float! img-obj/size/y / img-obj/size/x
                                cap-h: either img-cap [line-height][0]
                                ; reserve the caption line + the line below so the whole block fits the page
                                img-avail-h: max 1 (usable-top - page-bottom - line-height - cap-h)
                                img-avail-w: max 1 (page-width - margin-left - margin-right)
                                img-base-w: either decl-w [width-to-px decl-w 'px][
                                    ; no width: contain the image in the available height (and width), keep aspect
                                    iw: img-obj/size/x
                                    if img-obj/size/y > img-avail-h [iw: max 1 (to integer! (img-avail-h / img-aspect))]
                                    if iw > img-avail-w [iw: img-avail-w]
                                    if (to integer! (iw * img-aspect)) > img-avail-h [iw: max 1 (to integer! (img-avail-h / img-aspect))]
                                    iw
                                ]
                                ge: image-geometry reduce [base-color cap-info/3 cap-info/4] img-base-w img-aspect img-avail-h
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
                                    ge: image-geometry reduce [base-color cap-info/3 cap-info/4] img-base-w img-aspect img-avail-h
                                    block-h: ge/9
                                ]
                                img-w: ge/1  img-h: ge/2  bw: ge/3  bh: ge/4
                                bx: ge/5  by: ge/6  ix: ge/7  iy: ge/8
                                if base-color [
                                    emit page-content [pdf-kit/rgb base-color " rg "
                                        (pdf-kit/num (margin-left + bx)) " " (pdf-kit/num (page-y + by - bh)) " "
                                        (pdf-kit/num bw) " " (pdf-kit/num bh) " re f"]
                                ]
                                emit-image page-content (margin-left + ix) (page-y + iy) img-w img-h img-file
                                if img-cap [
                                    emit-styled-text page-content margin-left (page-y - block-h - line-height) img-cap bw "C" cap-styles
                                ]
                                page-y: page-y - block-h - line-height - cap-h
                            ][
                                print rejoin ["Warning: unsupported or unreadable image: " img-file]
                            ]
                        ]
                    ]
                    column [
                        col-args: line/args
                        col-rows: line/lines

                        ; args: [width] [gap] then optional column styles (m s b u i h1 h2 h3 ...)
                        col-styles: copy []
                        col-img-styles: line/img
                        col-img-w: report-styles/image-width col-img-styles
                        width-spec: 'auto
                        gap-spec: none
                        pos: 0
                        foreach a col-args [
                            either any [number? a issue? a a = 'auto][
                                pos: pos + 1
                                either pos = 1 [width-spec: a][either pos = 2 [gap-spec: a][]]
                            ][
                                append col-styles a
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
                            col-col-w: measure-column-pixels styled-rows col-img-w
                        ][
                            either any [number? width-spec issue? width-spec][
                                col-col-w: col-w-px width-spec cch
                            ][
                                col-col-w: measure-column-pixels styled-rows col-img-w
                            ]
                        ]
                        either all [any [number? gap-spec issue? gap-spec] gap-spec][
                            col-gap: col-w-px gap-spec cch
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
                        col-num: to integer! (page-width - margin-left - margin-right) / (col-col-w + col-gap)
                        if col-num < 1 [col-num: 1]
                        col-idx: 1
                        col-remaining: col-total
                        while [col-remaining > 0][
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
                ]
            ][
                if block? line [
                    lines: wrap-line line (either nowrap? line [1000000][col-w]) :line-measure
                    first?: true
                    foreach l lines [
                        if first? [page-y: page-y - heading-gap l]
                        adv: line-advance l
                        if (page-y - adv) < page-bottom [new-page]
                        render-pairs-line page-content l page-y
                        page-y: page-y - adv
                        first?: false
                    ]
                ]
            ]
        ]

        append pages page-content
        total-pages: length? pages

        pd-pages: assemble-pdf pages total-pages hdr ftr usable-top date-str time-str datetime-str
        pdf-kit/save-pdf output pd-pages
        if browser [browse output]
        reset-font
    ]
]; report-pdf

;=== Export ===

;generate: :report-pdf/generate