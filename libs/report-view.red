Red [
    File:      %report-view.red
    Title:     "Report Viewer (Refactored)"
    Purpose:   {Generate multi-page A4 reports using Red's
                draw dialect from compact parser structure.}
    Date:      2026-08-19
    Needs:     'View
    Tabs:      4
    Note:      {Adapted from report-generator/report-view.red.
                Works with parse-report structured output.
                No line-wide styles — each pair carries its own.
                Uses `func` consistently — `function`'s auto-local
                would shadow context-level state words (page-y, etc.).}
]

; Dependencies loaded by caller (report-test.red uses do, report.red uses #include)

#include %report-parser.red
#include %report-pdf.red

report-view: make report-styles [
    ;=== Draw-specific typography ===

    ; Familys chosen to match the PDF's Base-14 faces (metric clones on most
    ; systems): Times New Roman / Helvetica / Courier.
    font-face-serif: "Times New Roman"
    font-face-sans:  "Helvetica"
    font-face-mono:  "Courier"

    ; Per-family multipliers on every font size; sizes are rounded to whole
    ; points (GTK renders whole-point sizes only). The View measures ~1.3x wider
    ; per point than the PDF and the three faces differ slightly, so each family
    ; is tuned separately to match the PDF's serif/sans/mono.
    font-scale-serif:  1 ; 0.84
    font-scale-sans:   1 ; 0.84
    font-scale-mono:   1 ; 0.84

    ;=== Draw-specific state ===

    page-draw: none
    current-font: none
    measure-face: none
    font-cache: make map! []
    join-x: 0
    join-y: 0

    hotspots: copy []
    page-hotspots: copy []
    hint-delay: 1

    ; Layout state shared with _emit-* functions
    usable-top: 0
    page-bottom: 0

    ;=== Report generation state (context-level so _emit-* can access) ===

    page-y: 0
    page-num: 0
    total-pages: 0
    pages: copy []
    prev-line: none     ; previously drawn line (metrics-based baseline stepping)
    prev-draw?: false  ; previous BODY item was a DRAW (skip the block step-past)
    prev-box: none     ; [x y w h] draw-space box of the previous BODY item
    track-box?: false  ; when true, _emit-text-decorations records text box extents
    in-frame?: false   ; while laying out a FRAME's contents (defer page breaks)
    box-min-x: none  box-min-y: none  box-max-x: none  box-max-y: none
    bg-cmds: copy []    ; DRAW-BG draw commands (applied to every page)
    current-hdr: none
    current-ftr: none
    ; per-page header/footer variants (block1 for page 1, block2 for page 2+,
    ; superseded by in-body HEADER/FOOTER overrides from the next page onward)
    active-hdr: none
    active-ftr: none
    pending-hdr: none
    pending-ftr: none
    hdr-pending?: false
    ftr-pending?: false
    hdr-locked?: false
    ftr-locked?: false
    page-hdrs: none
    page-ftrs: none
    hdr1: none  hdr2: none  ftr1: none  ftr2: none

    mk-variant: func [
        "Wrap a line block as a header/footer variant object, or none when empty."
        blk [block! none!]
    ][
        either all [blk not empty? blk][object [lines: blk]][none]
    ]

    line-ascent: func [
        "Measured ascent of a parsed line block (for header top clamping)."
        line [block!]
        /local lm
    ][
        lm: line-ink line :view-metrics
        lm/2
    ]

    set-page-variants: does [
        "Pick the variants for the current page and apply any pending override."
        unless hdr-locked? [active-hdr: either page-num = 1 [hdr1][hdr2]]
        unless ftr-locked? [active-ftr: either page-num = 1 [ftr1][ftr2]]
        if hdr-pending? [active-hdr: pending-hdr  hdr-locked?: true  hdr-pending?: false]
        if ftr-pending? [active-ftr: pending-ftr  ftr-locked?: true  ftr-pending?: false]
    ]
    date-str: ""
    time-str: ""
    datetime-str: ""

    set-hint-delay: func [
        "Set hint hover delay in seconds"
        secs [integer!] "Delay in seconds (minimum 1)"
    ][
        hint-delay: max 1 secs
    ]

    ;=== Font management ===

    build-font: func [
        "Create font! for style combo and size (cached)"
        styles [block!] sz [integer!]
        /local name b? i? hd spec key cached fnt scale fam
    ][
        fam: style-family styles
        b?: style-has styles 'b
        i?: style-has styles 'i
        hd: style-heading styles
        if all [hd > 0 not b? fam <> 'mono not i?][b?: true]
        name: case [
            fam = 'mono [font-face-mono]
            fam = 'sans [font-face-sans]
            true      [font-face-serif]
        ]
        scale: case [
            fam = 'mono [font-scale-mono]
            fam = 'sans [font-scale-sans]
            true      [font-scale-serif]
        ]
        key: reduce [name sz any [b? false] any [i? false] scale]
        if cached: select font-cache key [return cached]

        spec: copy [name: "" size: 0]
        spec/2: name
        spec/4: to integer! round sz * scale
        if any [b? i?] [
            append spec to set-word! "style"
            append/only spec collect [if b? [keep 'bold] if i? [keep 'italic]]
        ]
        fnt: make font! spec
        put font-cache mold key fnt
        fnt
    ]

    set-font: func [
        "Set current-font and update measure-face"
        styles [block!] sz [integer!]
    ][
        current-font: build-font styles sz
        unless measure-face [measure-face: make face! [size: as-pair page-width page-height]]
        measure-face/font: current-font
    ]

    measure-text: func [
        "Measure pixel width of text using current font"
        text [string!]
        /local sz
    ][
        sz: size-text/with measure-face text
        to integer! sz/x
    ]

    measure-height: func [
        "Measure pixel height of current font"
        /local sz
    ][
        sz: size-text/with measure-face "Hg"
        to integer! sz/y
    ]

    view-metrics: func [
        "Measure text under a style block: [width height ascent] in px (View/OS fonts)"
        text [string!] styles [block!]
        /local any-style? sz h a w adv
    ][
        any-style?: any [
            style-has styles 'b  style-has styles 'i  style-has styles 'u
            style-nondefault-font? styles
        ]
        sz: font-size-for styles
        either any-style? [set-font styles sz][set-font [] font-size]
        h: to integer! second size-text/with measure-face "hg"   ; line box: ascender + descender
        ; Red's `size-text` reports the whole line box, not the ascender. The draw
        ; engine puts the baseline at `y + ascender`, so split the box by the
        ; family's ascender fraction; otherwise mixed families land a different
        ; descent above the line baseline.
        a: to integer! round (h * box-ascent-frac styles)         ; ascender
        ; mono: measure length x one glyph advance. The OS shaper applies
        ; ligatures (ff/fi/fl/ffi) and would otherwise report a narrower run
        ; than the font's cell width, making boxes/columns ragged and differing
        ; from the PDF's Base-14 advances.
        either (style-family styles) = 'mono [
            adv: measure-text "M"
            w: (length? text) * adv
        ][
            w: measure-text text
        ]
        reduce [w h a]
    ]

    safe-file-stem: func [
        "Reduce a report title to a safe single-segment file stem (no path traversal)."
        s [string!]
        /local r
    ][
        r: copy s
        replace/all r "/" "-"
        replace/all r (to char! 92) "-"    ; backslash
        replace/all r ".." "-"
        r
    ]

    line-measure: func [
        "Pixel width of text under a style block (for word wrap)."
        text [string!] styles [block!]
        /local any-style? sz adv
    ][
        any-style?: any [
            style-has styles 'b  style-has styles 'i  style-has styles 'u
            style-nondefault-font? styles
        ]
        sz: font-size-for styles
        either any-style? [set-font styles sz][set-font [] font-size]
        either (style-family styles) = 'mono [
            adv: measure-text "M"
            (length? text) * adv
        ][
            measure-text text
        ]
    ]

    avg-char-width: func [
        "Average alphabet advance (px per character) for a style/font — a property of the style, not the text"
        styles [block!] sz [integer!]
        /local any-style? tw
    ][
        any-style?: any [
            style-has styles 'b  style-has styles 'i  style-has styles 'u
            style-nondefault-font? styles
        ]
        either any-style? [set-font styles sz][set-font [] font-size]
        tw: measure-text alphabet
        tw * 1.0 / (length? alphabet)
    ]

    ;=== Column measurement (conservative per-char estimate; matches PDF) ===

    col-char-width: func [
        "Conservative per-character width for column layout"
        styles [block!]
    ][
        font-size * 0.583
    ]

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

    measure-column-pixels: func [
        "Measure max pixel width across column rows (pair format), style-aware"
        col-rows [block!] col-styles [block!] img-w [issue! none!]
        /local mx ln pair val sty txt val-w ia ia-obj wd m
    ][
        mx: 0
        foreach ln col-rows [
            val-w: 0
            either block? ln [
                foreach pair ln [
                    either block? pair [
                        if (length? pair) >= 1 [
                            val: pair/1
                            sty: either all [(length? pair) >= 2 block? pair/2][merge-styles col-styles pair/2][copy col-styles]
                            txt: either any [string? val number? val date?][format-pair-value val sty][mold val]
                            m: view-metrics txt sty
                            val-w: val-w + m/1
                        ]
                    ][
                        m: view-metrics (form pair) col-styles
                        val-w: val-w + m/1
                    ]
                ]
            ][
                either object? ln [
                    if ln/type = 'image [
                        ia: parse-image-args ln/args
                        either img-w [
                            ; use the column's default image width; add a slight box allowance
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
                        m: view-metrics ln col-styles
                        val-w: m/1
                    ]
                ]
            ]
            if val-w > mx [mx: val-w]
        ]
        to integer! mx
    ]

    col-width-px: func [
        "Convert a COLUMN width/gap spec to px, using real char width for the style set"
        spec [number! issue!] col-styles [block!]
        /local s u n
    ][
        either number? spec [
            to integer! spec * col-char-width col-styles
        ][
            s: form spec
            u: copy/part skip tail s -2 2
            either find ["px" "ch"] u [
                n: to integer! copy/part s ((length? s) - 2)
                either u = "ch" [to integer! n * col-char-width col-styles][n]
            ][
                print rejoin ["Warning: invalid width tag: " s]
                0
            ]
        ]
    ]

    width-to-px: func [
        "Normalize a width spec to px (used for image widths; px only in columns)"
        spec [number! issue!] default-unit [word!]
        /local s u n
    ][
        either number? spec [
            to integer! spec
        ][
            s: form spec
            u: copy/part skip tail s -2 2
            either find ["px" "ch"] u [
                n: to integer! copy/part s ((length? s) - 2)
                either u = "ch" [to integer! n * col-char-width []][n]
            ][
                print rejoin ["Warning: invalid width tag: " s]
                0
            ]
        ]
    ]

    to-draw-y: func [
        "Convert PS-style y (0 at bottom) to draw y (0 at top)"
        y [integer!]
    ][
        page-height - y
    ]

    gray-to-tuple: func [
        "Convert 0.0-1.0 gray float to RGB tuple"
        g [float!]
        /local v
    ][
        v: to integer! g * 255
        to tuple! reduce [v v v]
    ]

    ;=== Draw emit primitives ===

    draw-rect: func [
        "Append rectangle stroke to page-draw"
        x [integer!] y [integer!] w [integer!] h [integer!]
    ][
        append page-draw compose [
            pen black fill-pen off line-width (stroke-width)
            box (as-pair x (to-draw-y y + h)) (as-pair (x + w) (to-draw-y y))
        ]
    ]

    draw-vline: func [
        "Append vertical line to page-draw"
        x [integer!] y [integer!] h [integer!]
    ][
        append page-draw compose [
            pen black line-width (stroke-width)
            line (as-pair x (to-draw-y y)) (as-pair x (to-draw-y (y + h)))
        ]
    ]

    draw-filled-rect: func [
        "Append filled rectangle to page-draw"
        x [integer!] y [integer!] w [integer!] h [integer!] gray [float!]
    ][
        append page-draw compose [
            fill-pen (gray-to-tuple gray) pen off
            box (as-pair x (to-draw-y (y + h))) (as-pair (x + w) (to-draw-y y))
        ]
    ]

    draw-text-simple: func [
        "Append positioned text to page-draw (left-aligned)"
        x [integer!] y [integer!] text [string!] fg [tuple!]
    ][
        append page-draw compose [
            pen (fg) font (current-font)
            text (as-pair x (to-draw-y y)) (text)
        ]
    ]

    draw-image-func: func [
        "Append image to page-draw"
        x [integer!] y [integer!] display-w [integer!] display-h [integer!] file [file!]
        /local img dy
    ][
        img: attempt [load file]
        unless img [
            print rejoin ["Warning: cannot load image " file]
            return false
        ]
        dy: to-draw-y y
        append page-draw compose [
            image (img)
                (as-pair x dy)
                (as-pair (x + display-w) (dy + display-h))
        ]
        true
    ]

    ;=== Inline raw draw ([DRAW H [ops]] in BODY) ============================

    box-reset: does [
        box-min-x: box-min-y: box-max-x: box-max-y: none
    ]

    box-note: func [x0 [integer!] y0 [integer!] x1 [integer!] y1 [integer!]][
        box-min-x: either box-min-x [min box-min-x x0][x0]
        box-min-y: either box-min-y [min box-min-y y0][y0]
        box-max-x: either box-max-x [max box-max-x x1][x1]
        box-max-y: either box-max-y [max box-max-y y1][y1]
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
    draw-env: func [hh [integer!] /local e][
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
        set in e 'y to-draw-y page-y
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

    _compose-draw: func [ops [block!] hh [integer!]][
        compose/deep bind copy ops draw-env hh
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
        line [object!]
        /local h ops
    ][
        either empty? line/args [
            ops: _compose-draw line/lines 0
            either h: draw-ops-height ops 0 [h][0]
        ][
            line/args/1
        ]
    ]

    _emit-draw: func [
        "Render an inline [DRAW H [ops]] item; returns the height it consumed"
        line [object!]
        /local hh ops
    ][
        hh: draw-item-height line
        ops: _compose-draw line/lines hh
        append page-draw ops
        ; leave the draw state clean for the renderer commands that follow
        append page-draw compose [pen black fill-pen off line-width (stroke-width)]
        page-y: page-y - hh
        hh
    ]

    ;=== Draw styled text ===

    _emit-text-decorations: func [
        "Emit background, frame, underline, and record hotspot for a text segment"
        dx [integer!] dy [integer!] fh [integer!] tw [integer!]
        text [string!] fg [tuple!] styles [block!]
        link-id hint-id
        bt [integer!] bb [integer!]                    ; background/frame box top & bottom
        /local bg fc ul-x lid hid txt ut ul-y dd dashes         ; <-- add aliases
    ][
        bg: style-bg-color styles
        fc: style-frame-color styles
        if all [bg not opaque-tuple? bg][bg: none]
        if all [fc not opaque-tuple? fc][fc: none]

        if track-box? [box-note dx bt (dx + tw) bb]

        if fc [
            append page-draw compose [
                fill-pen (fc) pen off
                box (as-pair dx bt) (as-pair (dx + tw) bb)
            ]
        ]
        if bg [
            either fc [
                append page-draw compose [
                    fill-pen (bg) pen off
                    box (as-pair (dx + 2) (bt + 2)) (as-pair (dx + tw - 2) (bb - 2))
                ]
            ][
                append page-draw compose [
                    fill-pen (bg) pen off
                    box (as-pair dx bt) (as-pair (dx + tw) bb)
                ]
            ]
        ]

        lid: link-id                           ; <-- alias
        hid: hint-id                           ; <-- alias
        txt: text                              ; <-- alias
        if any [lid hid][
            append/only hotspots make object! [
                link-id: lid hint-id: hid      ; <-- use aliases
                x: dx y: dy - fh w: tw h: fh text: txt
            ]
        ]

        ut: either style-underline-shown? styles [style-underline-type styles]['none]
        if ut <> 'none [
            ul-x: dx
            ul-y: dy + 2
            either ut = 'solid [
                append page-draw compose [
                    pen (fg) line (as-pair ul-x ul-y) (as-pair (ul-x + tw) ul-y)
                ]
            ][
                ; dotted underline: 2px dashes, 2px gaps
                dashes: max 1 to integer! (tw / 4)
                dd: 0
                while [dd < dashes][
                    append page-draw compose [
                        pen (fg) line (as-pair (ul-x + (dd * 4)) ul-y) (as-pair (ul-x + (dd * 4) + 2) ul-y)
                    ]
                    dd: dd + 1
                ]
            ]
        ]
    ]

    draw-styled-text: func [
        "Render text with style-aware font, alignment, colors, underline"
        x [integer!] y [integer!] text [string!]
        col-w-arg [integer!] align [string!] styles [block!]
        /join "Continue from join-x/join-y position"
        /local any-style? wpx seg-w n fg sz fh tw dx dy link-id hint-id ascent m bt bb

    ][
        if (length? text) = 0 [exit]

        any-style?: any [
            style-has styles 'b
            style-has styles 'i
            style-has styles 'u
            style-nondefault-font? styles
        ]
        fg: any [style-fg-color styles 0.0.0]
        sz: font-size-for styles

        ; one measurement drives the text, the baseline offset and the box
        m: view-metrics text styles
        tw: m/1                 ; advance width
        fh: m/2                 ; line box (ascender + descender)
        ascent: m/3             ; ascender above the baseline

        ; The box is the line box around the baseline: [dy - ascent, dy + descent].

        ; width box: px/N is literal; a bare integer or ch/N means N average
        ; characters of this style/font (the alphabet average, not the value text)
        wpx: style-width-px styles
        if wpx = 0 [
            n: style-chars styles
            if n > 0 [wpx: to integer! (n * avg-char-width styles sz)]
        ]
        seg-w: either wpx > tw [wpx][tw]

        link-id: none
        hint-id: none
        foreach s styles [
            if word? s [
                parse form s [
                    "link" "-" copy sid to end (link-id: to-id sid)
                    | "hint" "-" copy sid to end (hint-id: to-id sid)
                ]
            ]
        ]

        either join [
            dx: join-x
            case [
                all [wpx > tw align = "C"][dx: join-x + to integer! (wpx - tw) / 2]
                all [wpx > tw align = "R"][dx: join-x + wpx - tw]
            ]
            dy: to-draw-y join-y

            bt: dy - ascent
            bb: dy - ascent + fh

            _emit-text-decorations dx dy fh tw text fg styles link-id hint-id bt bb
            append page-draw compose [
                pen (fg) font (current-font)
                text (as-pair dx (dy - ascent)) (text)
            ]
            join-x: join-x + seg-w
        ][
            dx: x
            case [
                all [wpx > 0 align = "C"][dx: x + to integer! (wpx - tw) / 2]
                all [wpx > 0 align = "R"][dx: x + wpx - tw]
                align = "C" [dx: x + to integer! (col-w-arg - tw) / 2]
                align = "R" [dx: x + col-w-arg - tw]
            ]
            dy: to-draw-y y

            bt: dy - ascent
            bb: dy - ascent + fh

            _emit-text-decorations dx dy fh tw text fg styles link-id hint-id bt bb
            append page-draw compose [
                pen (fg) font (current-font)
                text (as-pair dx (dy - ascent)) (text)
            ]

            if any-style? [set-font [] font-size]
        ]
    ]

    ;=== Content/header/footer line renderers (pair format) ===

    draw-pairs-line: func [
        "Render a text line (block of pairs) at position"
        line [block!] y-pos [integer!]
        /local nsegs pair styles text
    ][
        nsegs: length? line
        if nsegs > 0 [
            either nsegs = 1 [
                pair: line/1
                styles: resolve-colors either all [(length? pair) >= 2 block? pair/2][pair/2][copy []]
                text: format-pair-value pair/1 styles
                draw-styled-text margin-left y-pos text col-w (style-align-for pair/1 styles) styles
            ][
                join-x: margin-left
                join-y: y-pos
                foreach pair line [
                    styles: resolve-colors either all [(length? pair) >= 2 block? pair/2][pair/2][copy []]
                    text: format-pair-value pair/1 styles
                    draw-styled-text/join margin-left y-pos text col-w (style-align-for pair/1 styles) styles
                ]
            ]
        ]
    ]

    draw-header-pairs: func [
        "Render a header/footer line with positional alignment (1st=L, 2nd=C, 3rd=R)"
        y [integer!] line [block!]
        page-num-arg [integer!] total-pages-arg [integer!]
        date-str-arg [string!] time-str-arg [string!] datetime-str-arg [string!]
        /default-style def-styles [block!]
        /local nsegs idx pair styles text align
    ][
        nsegs: length? line
        if nsegs > 0 [
            repeat idx nsegs [
                pair: pick line idx
                styles: resolve-colors either all [(length? pair) >= 2 block? pair/2][pair/2][copy []]
                text: format-pair-value pair/1 styles
                if number? text [text: form text]
                align: case [idx = 1 ["L"] idx = 2 ["C"] idx = 3 ["R"] true ["L"]]
                text: replace-tokens text page-num-arg total-pages-arg date-str-arg time-str-arg datetime-str-arg
                either all [empty? styles default-style][
                    draw-styled-text margin-left y text col-w align def-styles
                ][
                    draw-styled-text margin-left y text col-w align styles
                ]
            ]
        ]
    ]

    ;=== Header / Footer rendering ===

    draw-header: func [
        {Reserve the header height at the top of a page and return the updated y.
         With /tokens the header is actually drawn, resolving <page>/<pages>; use
         that in the second pass, once total-pages is known (drawing in the first
         pass and string-replacing the tokens afterwards breaks right/centre
         alignment, because the x was measured from the raw token text).}
        hdr [object! none!] y-pos [integer!]
        d-str [string!] t-str [string!] dt-str [string!]
        /tokens pn [integer!] tp [integer!]
        /local line prev-l
    ][
        if none? hdr [return y-pos]
        prev-l: none
        foreach line hdr/lines [
            if prev-l [y-pos: y-pos - line-step line prev-l :view-metrics]
            if tokens [
                draw-header-pairs/default-style y-pos line pn tp d-str t-str dt-str ['b]
            ]
            prev-l: line
        ]
        if tokens [set-font [] font-size]
        y-pos
    ]

    draw-footer: func [
        "Render footer block at bottom of page"
        ftr [object! none!] pn [integer!] tp [integer!]
        d-str [string!] t-str [string!] dt-str [string!]
        /local line ys i n lm
    ][
        if any [none? ftr empty? ftr/lines] [exit]
        ; stack line boxes upward from margin-bottom: place each baseline from its
        ; descent, then step up by the distance between consecutive baselines
        n: length? ftr/lines
        ys: copy []
        repeat k n [append ys 0]
        lm: line-ink (pick ftr/lines n) :view-metrics
        poke ys n (margin-bottom + lm/3)
        i: n
        while [i > 1][
            poke ys (i - 1) ((pick ys i) + line-step (pick ftr/lines i) (pick ftr/lines (i - 1)) :view-metrics)
            i: i - 1
        ]
        i: 0
        foreach line ftr/lines [
            i: i + 1
            draw-header-pairs (pick ys i) line pn tp d-str t-str dt-str
        ]
    ]

    ;=== Table rendering (pair format) ===

    _merge-cell-styles: func [
        "Merge column defaults with cell styles, returning [raw-val cell-styles final-styles text-styles]"
        col-bold? [logic!] col-i [integer!] row [block!]
        /local pair cell-styles raw-val final-styles text-styles tuple-n
    ][
        cell-styles: either col-i <= (length? row) [
            pair: pick row col-i
            resolve-colors either all [(length? pair) >= 2 block? pair/2][pair/2][copy []]
        ][copy []]

        raw-val: either col-i <= (length? row) [
            pair: pick row col-i
            pair/1
        ][none]

        final-styles: copy []
        if col-bold? [append final-styles 'b]
        foreach s cell-styles [
            either tuple? s [
                append final-styles s
            ][
                unless any [find final-styles s  s = 'blank  s = 's1000  s = 'money] [append final-styles s]
            ]
        ]

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

        reduce [raw-val cell-styles final-styles text-styles]
    ]

    draw-table-row: func [
        "Render a table row (header or data)"
        y [integer!] rh [integer!]
        tl [integer!] tw [integer!] boxed? [logic!] alt? [logic!]
        is-header [logic!] row-num [integer!]
        col-info [block!] row [block!]
        /local box-top text-y col-titles col-widths col-aligns col-formats col-bolds col-blanks num-cols
               col-x col-i c-w col-align col-format col-text merged raw-val cell-styles
               final-styles text-styles text cell-fmt cell-bg cell-fc
               hs-before hs-after hs-i hs col-r
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
            draw-filled-rect tl box-top tw rh header-gray
        ][
            if all [alt? (row-num // 2) = 0] [
                draw-filled-rect tl box-top tw rh alt-row-gray
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
                draw-styled-text (col-x + cell-pad) text-y col-text (c-w - (cell-pad * 2)) col-align ['b]
            ][
                merged: _merge-cell-styles pick col-bolds col-i col-i row
                raw-val: merged/1
                cell-styles: merged/2
                final-styles: merged/3
                text-styles: merged/4

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
                    date? raw-val   [
                        case [
                            find cell-styles 'date     [format-date-value raw-val 'date]
                            find cell-styles 'time     [format-date-value raw-val 'time]
                            find cell-styles 'datetime [format-date-value raw-val 'datetime]
                            true                       [form raw-val]
                        ]
                    ]
                    true            [form raw-val]
                ]

                cell-bg: style-bg-color final-styles
                cell-fc: style-frame-color final-styles
                if all [cell-bg not opaque-tuple? cell-bg][cell-bg: none]
                if all [cell-fc not opaque-tuple? cell-fc][cell-fc: none]
                if cell-fc [
                    append page-draw compose [
                        fill-pen (cell-fc) pen off
                        box (as-pair col-x (to-draw-y (box-top + rh))) (as-pair (col-x + c-w) (to-draw-y box-top))
                    ]
                ]
                if cell-bg [
                    either cell-fc [
                        append page-draw compose [
                            fill-pen (cell-bg) pen off
                            box (as-pair (col-x + 2) (to-draw-y (box-top + rh - 2))) (as-pair (col-x + c-w - 2) (to-draw-y box-top + 2))
                        ]
                    ][
                        append page-draw compose [
                            fill-pen (cell-bg) pen off
                            box (as-pair col-x (to-draw-y (box-top + rh))) (as-pair (col-x + c-w) (to-draw-y box-top))
                        ]
                    ]
                ]
                hs-before: length? hotspots
                draw-styled-text (col-x + cell-pad) text-y text (c-w - (cell-pad * 2)) (style-align final-styles col-align) text-styles
                hs-after: length? hotspots
                if hs-after > hs-before [
                    hs-i: hs-before + 1
                    while [hs-i <= hs-after][
                        hs: pick hotspots hs-i
                        hs/x: col-x
                        hs/y: to-draw-y (box-top + rh)
                        hs/w: c-w
                        hs/h: rh
                        hs-i: hs-i + 1
                    ]
                ]
            ]
            col-x: col-x + c-w
            col-i: col-i + 1
        ]

        if boxed? [draw-rect tl box-top tw rh]

        col-x: tl
        col-i: 2
        while [col-i <= num-cols][
            c-w: pick col-widths (col-i - 1)
            col-x: col-x + c-w
            draw-vline col-x box-top rh
            col-i: col-i + 1
        ]
    ]

    ;=== Page management ===

    new-page: does [
        "Finalize current page and start a new one"
        append/only pages page-draw
        append/only page-hotspots hotspots
        append/only page-hdrs active-hdr
        append/only page-ftrs active-ftr
        hotspots: copy []
        page-num: page-num + 1
        set-page-variants
        page-draw: compose [fill-pen white pen off box 0x0 (as-pair page-width page-height)]
        if not empty? bg-cmds [append page-draw bg-cmds]
        set-font [] font-size
        prev-line: none
        prev-draw?: false
        prev-box: none
        page-y: usable-top
        if active-hdr [
            page-y: page-height - margin-top - (line-ascent active-hdr/lines/1)
            page-y: draw-header active-hdr page-y date-str time-str datetime-str
            prev-line: last active-hdr/lines
        ]
    ]

    ;=== Extracted content emitters ===

    _emit-pairs: func [
        "Render pairs line from content (word-wrapped to the content width)"
        line [block!]
        /local lines l lm
    ][
        lines: wrap-line line (either nowrap? line [1000000][col-w]) :line-measure
        foreach l lines [
            if prev-line [page-y: page-y - line-step l prev-line :view-metrics]
            lm: line-ink l :view-metrics
            if all [(page-y - lm/3) < page-bottom  not in-frame?][
                new-page
                if prev-line [page-y: page-y - line-step l prev-line :view-metrics]
            ]
            draw-pairs-line l page-y
            prev-line: l
        ]
    ]

    _emit-table: func [
        "Render table object from content"
        line [object!]
        /local mods boxed? alt? table-rows header-row col-info table-left table-width
               row-h table-data row-item row-num first-data first-h
    ][
        mods: table-modifiers line/args
        boxed?: mods/1
        alt?: mods/2

        table-rows: line/lines
        if empty? table-rows [exit]

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
            either first-data [row-height first-data :view-metrics][row-h]
        ]
        if (page-y - row-h - first-h - line-height) < page-bottom [new-page]

        draw-table-row page-y row-h table-left table-width boxed? alt? true 0 col-info []
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
                draw-table-row page-y row-h table-left table-width boxed? alt? true 0 col-info []
                page-y: page-y - row-h
            ][
                row-h: row-height row-item :view-metrics
                if (page-y - row-h) < page-bottom [
                    new-page
                    row-h: header-row-h
                    draw-table-row page-y row-h table-left table-width boxed? alt? true 0 col-info []
                    page-y: page-y - row-h
                    row-h: row-height row-item :view-metrics
                ]

                row-num: row-num + 1
                draw-table-row page-y row-h table-left table-width boxed? alt? false row-num col-info row-item
                page-y: page-y - row-h
            ]
        ]
        page-y: page-y - line-height
    ]

    _emit-image: func [
        "Render image object from content"
        line [object!]
        /local ia img-file img-obj aspect avail-h avail-w base-w w
               ge base-color img-cap img-w img-h bw bh bx by ix iy block-h cap-h cap-info cap-styles
               decl-w left-a right-a top-a bot-a avail-full cap-line
    ][
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
                aspect: to float! img-obj/size/y / img-obj/size/x
                cap-line: either img-cap [reduce [reduce [img-cap cap-styles]]][copy []]
                cap-h: either img-cap [line-advance cap-line :view-metrics][0]
                ; reserve the caption line + the line below so the whole block fits the page
                avail-w: max 1 (page-width - margin-left - margin-right)
                avail-full: max 1 (usable-top - page-bottom - line-height - cap-h)
                ; no width argument: fit what is left on THIS page (put it first for a
                ; full-page image). A declared width is contained to the page instead.
                avail-h: either decl-w [avail-full][max 1 (page-y - page-bottom - line-height - cap-h)]
                base-w: either decl-w [width-to-px decl-w 'px][
                    ; no width: contain the image in the available height (and width), keep aspect
                    w: img-obj/size/x
                    if img-obj/size/y > avail-h [w: max 1 (to integer! (avail-h / aspect))]
                    if w > avail-w [w: avail-w]
                    if (to integer! (w * aspect)) > avail-h [w: max 1 (to integer! (avail-h / aspect))]
                    w
                ]
                ge: image-geometry reduce [base-color cap-info/3 cap-info/4] base-w aspect avail-h
                block-h: ge/9
                ; if it does not fit this page, start a fresh page and re-size to its post-header area
                if (page-y - block-h - line-height - cap-h) < page-bottom [
                    new-page
                    avail-h: max 1 (page-y - page-bottom - line-height - cap-h)
                    base-w: either decl-w [width-to-px decl-w 'px][
                        w: img-obj/size/x
                        if img-obj/size/y > avail-h [w: max 1 (to integer! (avail-h / aspect))]
                        if w > avail-w [w: avail-w]
                        if (to integer! (w * aspect)) > avail-h [w: max 1 (to integer! (avail-h / aspect))]
                        w
                    ]
                    ge: image-geometry reduce [base-color cap-info/3 cap-info/4] base-w aspect avail-h
                    block-h: ge/9
                ]
                img-w: ge/1  img-h: ge/2  bw: ge/3  bh: ge/4
                bx: ge/5  by: ge/6  ix: ge/7  iy: ge/8
                if base-color [
                    append page-draw compose [
                        fill-pen (base-color) pen off
                        box (as-pair (margin-left + bx) (to-draw-y (page-y + by)))
                             (as-pair (margin-left + bx + bw) (to-draw-y (page-y + by - bh)))
                    ]
                ]
                draw-image-func (margin-left + ix) (page-y + iy) img-w img-h img-file
                if img-cap [
                    draw-styled-text margin-left (page-y - block-h - cap-h) img-cap bw "C" cap-styles
                ]
                ; make the whole image area a link/hint hotspot
                if any [cap-info/6 cap-info/7] [
                    left-a: margin-left + min bx ix
                    right-a: margin-left + max (bx + bw) (ix + img-w)
                    top-a: page-y + max by iy
                    bot-a: page-y + min (by - bh) (iy - img-h)
                    append/only hotspots make object! [
                        link-id: cap-info/6
                        hint-id: cap-info/7
                        x: left-a
                        y: to-draw-y top-a
                        w: right-a - left-a
                        h: top-a - bot-a
                        text: img-cap
                    ]
                ]
                page-y: page-y - block-h - line-height - cap-h
            ][
                print rejoin ["Warning: unsupported or unreadable image: " img-file]
            ]
        ]
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

    _emit-column-image: func [
        "Render an image row inside a column; returns the (uniform) row height consumed"
        x [integer!] y [integer!] row [object!] col-w [integer!] col-styles [block! none!] col-img-w [issue! none!] img-row-h [integer!]
        /local ia img-file img-obj ge block-h img-cap cap-h img-w img-h bw bh bx by ix iy base-color ci cap-styles
               left-a right-a top-a bot-a ch cw asp
    ][
        ia: parse-image-args row/args
        either all [not empty? ia ia/2][
            img-file: ia/2
            img-obj: attempt [load img-file]
            either img-obj [
                ci: image-caption-info build-image-caption row col-styles
                base-color: ci/2
                img-cap: ci/1
                cap-styles: ci/5
                cap-h: either img-cap [line-height][0]
                asp: to float! img-obj/size/y / img-obj/size/x
                ; the image fits the column's default width, else is contained to the column cell
                ch: max 1 (img-row-h - line-height - cap-h)
                base-w: either col-img-w [width-to-px col-img-w 'px][
                    cw: col-w
                    if img-obj/size/x < cw [cw: img-obj/size/x]
                    if (to integer! (cw * asp)) > ch [cw: max 1 (to integer! (ch / asp))]
                    cw
                ]
                ge: image-geometry reduce [base-color ci/3 ci/4] (min base-w col-w) asp ch
                img-w: ge/1  img-h: ge/2  bw: ge/3  bh: ge/4
                bx: ge/5  by: ge/6  ix: ge/7  iy: ge/8  block-h: ge/9
                if base-color [
                    append page-draw compose [
                        fill-pen (base-color) pen off
                        box (as-pair (x + bx) (to-draw-y (y + by)))
                             (as-pair (x + bx + bw) (to-draw-y (y + by - bh)))
                    ]
                ]
                draw-image-func (x + ix) (y + iy) img-w img-h img-file
                if img-cap [draw-styled-text x (y - block-h - line-height) img-cap bw "C" cap-styles]
                ; make the whole image area a link/hint hotspot (adjusted by _emit-column afterwards)
                if any [ci/6 ci/7] [
                    left-a: x + min bx ix
                    right-a: x + max (bx + bw) (ix + img-w)
                    top-a: y + max by iy
                    bot-a: y + min (by - bh) (iy - img-h)
                    append/only hotspots make object! [
                        link-id: ci/6
                        hint-id: ci/7
                        x: left-a
                        y: to-draw-y top-a
                        w: right-a - left-a
                        h: top-a - bot-a
                        text: img-cap
                    ]
                ]
                img-row-h
            ][
                print rejoin ["Warning: unsupported or unreadable image: " img-file]
                img-row-h
            ]
        ][
            img-row-h
        ]
    ]

    _emit-column: func [
        "Render column object from content"
        line [object!]
        /local col-args col-rows col-col-w col-gap col-total col-num col-idx col-remaining
               col-rows-per-col col-avail col-cols-fit col-rendered col-ci col-ri col-r
               col-emit-y col-offset col-draw saved-pd hs-before hs-after hs-i hs
               row used-h col-max-h ri rr end overflow? col-styles col-img-styles col-img-w col-img-row-h width-spec gap-spec pos
    ][
        col-args: line/args
        col-rows: line/lines
        ; image rows are styled only by the column's "image [styles]" clause, never by the text args
        col-img-styles: line/img
        ; the column's default image width (from the "image [styles]" clause), or none
        col-img-w: report-styles/image-width col-img-styles

        ; args: [width] [gap] then optional column styles (m s b u i h1 h2 h3 ...)
        ; width: bare number = ch units, px/N / ch/N explicit, 'auto = auto-measure
        ; gap:   bare number = ch units, px/N / ch/N explicit, default 1ch
        col-styles: copy []
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
        either width-spec = 'auto [
            col-col-w: measure-column-pixels col-rows col-styles col-img-w
        ][
            col-col-w: col-width-px width-spec col-styles
        ]
        either all [any [number? gap-spec issue? gap-spec] gap-spec][
            col-gap: col-width-px gap-spec col-styles
        ][
            col-gap: col-char-width col-styles
        ]
        if col-gap < col-char-width col-styles [col-gap: col-char-width col-styles]

        ; predetermined uniform row height for image rows = the max contained image height in the column
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
            if (col-row-height col-rows/:col-idx col-col-w col-img-styles col-img-row-h) > (page-y - page-bottom) [
                if page-y < usable-top [new-page]
            ]
            col-avail: page-y - page-bottom

            ; balanced rows-per-column, height-aware
            col-rows-per-col: ceil-div col-remaining col-num
            if col-rows-per-col < 1 [col-rows-per-col: 1]
            while [col-rows-per-col > 1][
                overflow?: false
                repeat col-ci col-num [
                    ri: col-idx + ((col-ci - 1) * col-rows-per-col)
                    if ri > col-total [break]
                    end: min (ri + col-rows-per-col) (col-total + 1)
                    used-h: 0
                    while [ri < end][
                        used-h: used-h + col-row-height col-rows/:ri col-col-w col-img-styles col-img-row-h
                        if used-h > col-avail [overflow?: true]
                        ri: ri + 1
                    ]
                ]
                if not overflow? [break]
                col-rows-per-col: col-rows-per-col - 1
            ]
            if col-rows-per-col < 1 [col-rows-per-col: 1]

            col-cols-fit: col-num
            col-rendered: 0
            col-max-h: 0
            repeat col-ci col-cols-fit [
                col-offset: (col-ci - 1) * (col-col-w + col-gap)
                col-draw: copy []
                saved-pd: page-draw
                hs-before: length? hotspots
                page-draw: col-draw
                used-h: 0
                ri: col-idx + ((col-ci - 1) * col-rows-per-col)
                rr: 0
                while [all [(rr < col-rows-per-col) ((ri + rr) <= col-total)]][
                    row: col-rows/(ri + rr)
                    either block? row [
                        draw-pairs-line (col-apply-styles row col-styles) (page-y - used-h)
                        used-h: used-h + line-height
                    ][
                        switch row/type [
                            image [
                                used-h: used-h + _emit-column-image margin-left (page-y - used-h) row col-col-w col-img-styles col-img-w col-img-row-h
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
                if col-offset > 0 [
                    hs-after: length? hotspots
                    hs-i: hs-before + 1
                    while [hs-i <= hs-after][
                        hs: pick hotspots hs-i
                        hs/x: hs/x + col-offset
                        hs-i: hs-i + 1
                    ]
                ]
                page-draw: saved-pd
                if not empty? col-draw [
                    append page-draw reduce ['push reduce ['translate as-pair col-offset 0 col-draw]]
                ]
            ]
            col-rendered: min (col-rows-per-col * col-cols-fit) col-remaining
            col-idx: col-idx + col-rendered
            col-remaining: col-remaining - col-rendered
            page-y: page-y - col-max-h
            if col-remaining > 0 [new-page]
        ]
    ]

    ;=== Token replacement in draw blocks ===

    replace-tokens-in-draw: func [
        "Replace tokens in all strings within a draw block"
        blk [block!] pn [integer!] tp [integer!]
        d-str [string!] t-str [string!] dt-str [string!]
        /local i v
    ][
        i: 1
        while [i <= length? blk][
            v: pick blk i
            case [
                string? v [
                    poke blk i replace-tokens v pn tp d-str t-str dt-str
                ]
                block? v [
                    replace-tokens-in-draw v pn tp d-str t-str dt-str
                ]
            ]
            i: i + 1
        ]
    ]

    ;=== Main entry point ===

    generate: func [
        "Generate a multi-page report using draw dialect. Returns block of draw blocks."
        page-obj [object!] "Parsed page from parse-report"
        /local first-line first-sz line paper ascent lm dh y0 ww
               hdr-ascent ftr-band hblk fblk a-h a-f hy
    ][
        current-hdr: page-obj/header
        current-ftr: page-obj/footer
        ; header/footer variants: block 2 (when present) is shown from page 2 on
        hdr1: mk-variant current-hdr/lines
        hdr2: either none? current-hdr/lines2 [hdr1][mk-variant current-hdr/lines2]
        ftr1: mk-variant current-ftr/lines
        ftr2: either none? current-ftr/lines2 [ftr1][mk-variant current-ftr/lines2]
        ; paper size/orientation comes from the page description
        paper: page-obj/paper
        either paper/2 = 'landscape [paper-format/landscape paper/1][paper-format paper/1]

        ; Direct assignment replaces `set in self`
        margin-left:   max any [page-obj/margin/left   50] edge-pad
        margin-right:  max any [page-obj/margin/right  50] edge-pad
        margin-top:    max any [page-obj/margin/top    50] edge-pad
        margin-bottom: max any [page-obj/margin/bottom 50] edge-pad

        ; line spacing = base size x factor (per-renderer factor; the font scales
        ; already match the glyph sizes, so scaling here would double-count)
        line-height: max 1 to integer! (font-size * line-height-factor)

        ; Clear font cache for fresh report generation
        font-cache: make map! []

        ; header top clamp: the tallest variant's first line (so no variant rises
        ; above the top margin); footer band: the tallest footer, since page-bottom
        ; is a fixed limit. In-body overrides are included in both maxima.
        hdr-ascent: 0
        hblk: either hdr1 [hdr1/lines][none]
        if hblk [hdr-ascent: max hdr-ascent (line-ascent hblk/1)]
        hblk: either hdr2 [hdr2/lines][none]
        if hblk [hdr-ascent: max hdr-ascent (line-ascent hblk/1)]
        ftr-band: 0
        fblk: either ftr1 [ftr1/lines][none]
        if fblk [ftr-band: max ftr-band footer-height object [lines: fblk] :view-metrics]
        fblk: either ftr2 [ftr2/lines][none]
        if fblk [ftr-band: max ftr-band footer-height object [lines: fblk] :view-metrics]
        foreach line page-obj/content/lines [
            if object? line [
                case [
                    line/type = 'header [
                        if not empty? line/lines [
                            hdr-ascent: max hdr-ascent (line-ascent line/lines/1)
                        ]
                    ]
                    line/type = 'footer [
                        if not empty? line/lines [
                            ftr-band: max ftr-band footer-height object [lines: line/lines] :view-metrics
                        ]
                    ]
                ]
            ]
        ]

        first-line: any [
            all [hdr1 not empty? hdr1/lines  hdr1/lines/1]
            all [page-obj/content  not empty? page-obj/content/lines  block? page-obj/content/lines/1  page-obj/content/lines/1]
        ]
        ; place the top of the first line at margin-top: reserve its measured ascent
        lm: default-metrics "Hg" copy []
        ascent: lm/3
        if first-line [
            lm: line-ink first-line :view-metrics
            ascent: lm/2
        ]
        if hdr-ascent > 0 [ascent: hdr-ascent]
        usable-top: page-height - margin-top - ascent
        ; reserve the full footer band (all its lines, incl. a leading empty line)
        page-bottom: margin-bottom + ftr-band

        date-str: form now/date
        time-str: copy/part form now/time ((length? form now/time) - 3)
        datetime-str: rejoin [date-str " " time-str]

        ; DRAW-BG: evaluate its parens once (page-width/height, margins are in scope)
        bg-cmds: copy []
        if all [object? page-obj/draw-bg not empty? page-obj/draw-bg/lines][
            bg-cmds: compose/deep bind copy page-obj/draw-bg/lines report-view
        ]

        pages: copy []
        page-draw: compose [fill-pen white pen off box 0x0 (as-pair page-width page-height)]
        if not empty? bg-cmds [append page-draw bg-cmds]
        page-hotspots: copy []
        hotspots: copy []
        page-hdrs: copy []
        page-ftrs: copy []
        page-num: 1
        hdr-locked?: ftr-locked?: false
        hdr-pending?: ftr-pending?: false
        active-hdr: hdr1
        active-ftr: ftr1
        set-font [] font-size

        prev-draw?: false
        prev-box: none
        prev-line: none
        page-y: usable-top
        if active-hdr [
            page-y: page-height - margin-top - (line-ascent active-hdr/lines/1)
            page-y: draw-header active-hdr page-y date-str time-str datetime-str
            prev-line: last active-hdr/lines
        ]

        ww: max 1 (page-width - margin-left - margin-right)

        ; one content item (text line or block); box accumulation is the caller's job
        emit-item: func [line [block! object!] /local y0][
            ; an in-body HEADER/FOOTER stages an override for the next page onward
            if all [object? line find [header footer] line/type][
                either line/type = 'header [
                    pending-hdr: mk-variant line/lines
                    hdr-pending?: true
                ][
                    pending-ftr: mk-variant line/lines
                    ftr-pending?: true
                ]
                exit
            ]
            either object? line [
                ; step past the preceding text line box before stacking a block.
                ; DRAW draws from its top, so it hugs the previous line
                ; (descent + gap); other blocks use half the line box.
                if all [prev-line not prev-draw?] [
                    lm: line-ink prev-line :view-metrics
                    page-y: page-y - either line/type = 'draw [
                        lm/3 + line-gap-px
                    ][
                        lm/2 + line-gap-px
                    ]
                ]
                prev-line: none
                y0: page-y
                switch line/type [
                    table     [_emit-table line]
                    image     [_emit-image line]
                    column    [_emit-column line]
                    draw [
                        dh: draw-item-height line
                        ; start a new page if the draw does not fit here
                        if (dh > (page-y - page-bottom)) [new-page]
                        y0: page-y
                        _emit-draw line
                    ]
                    pagebreak [
                        either empty? line/args [
                            new-page
                        ][
                            if (page-y - (line/args/1 * line-height)) < page-bottom [new-page]
                        ]
                    ]
                    frame [_emit-frame line]
                ]
                ; a PAGEBREAK already started a new page and set prev-line to the
                ; last header line; keep it so the next text steps below the header
                unless any [line/type = 'frame  line/type = 'pagebreak][
                    prev-draw?: line/type = 'draw
                    ; record the item's box for a following DRAW's prev-* words
                    box-note margin-left (to-draw-y y0) (margin-left + ww) (to-draw-y page-y)
                    ; after a DRAW leave a zero-descent marker so the next text line
                    ; steps below the art (a following block skips the step)
                    either prev-draw? [prev-line: copy []][prev-line: none]
                ]
            ][
                if block? line [
                    track-box?: true
                    _emit-pairs line
                    track-box?: false
                    prev-draw?: false
                ]
            ]
        ]

        ; a run of content items; /accumulate keeps one box spanning the whole run
        emit-items: func [lines [block!] /accumulate /local line][
            if accumulate [box-reset  track-box?: true]
            foreach line lines [
                unless accumulate [box-reset]
                if accumulate [track-box?: true]
                emit-item line
                unless accumulate [
                    unless all [object? line  find [frame header footer] line/type][box-finish]
                ]
            ]
            if accumulate [track-box?: false  box-finish]
        ]

        ; FRAME: lay the items out to measure them, then draw the backdrop behind them
        _emit-frame: func [line [object!] /local pad y0 saved buffered fcx fcy fcw fch env][
            pad: either empty? line/args [0][line/args/1]
            ; lay the contents out without internal page breaks so the whole frame
            ; can be measured and moved as one unit
            in-frame?: true
            y0: page-y
            saved: page-draw
            page-draw: copy []
            emit-items/accumulate line/lines
            buffered: page-draw
            page-draw: saved
            ; if it overflowed and we were not already at the page top, redo on a fresh page
            if all [(page-y < page-bottom) (y0 < usable-top)] [
                new-page
                y0: page-y
                saved: page-draw
                page-draw: copy []
                emit-items/accumulate line/lines
                buffered: page-draw
                page-draw: saved
            ]
            in-frame?: false
            either box-min-x [
                fcx: box-min-x  fcy: box-min-y
                fcw: box-max-x - box-min-x  fch: box-max-y - box-min-y
            ][
                fcx: margin-left  fcw: ww  fcy: to-draw-y y0  fch: y0 - page-y
            ]
            env: frame-env (fcx - pad) (fcy - pad) (fcw + (2 * pad)) (fch + (2 * pad)) fcx fcy fcw fch pad
            append page-draw compose/deep bind copy line/ops env
            append page-draw buffered
            prev-box: reduce [fcx - pad  fcy - pad  fcw + (2 * pad)  fch + (2 * pad)]
            prev-draw?: true
            prev-line: copy []
        ]

        emit-items page-obj/content/lines

        append/only pages page-draw
        append/only page-hotspots hotspots
        append/only page-hdrs active-hdr
        append/only page-ftrs active-ftr
        total-pages: length? pages

        pn: 0
        foreach page pages [
            pn: pn + 1
            replace-tokens-in-draw page pn total-pages date-str time-str datetime-str
        ]

        pn: 0
        foreach page pages [
            pn: pn + 1
            page-draw: page
            a-h: pick page-hdrs pn
            a-f: pick page-ftrs pn
            if a-h [
                hy: page-height - margin-top - (line-ascent a-h/lines/1)
                draw-header/tokens a-h hy date-str time-str datetime-str pn total-pages
            ]
            if a-f [
                draw-footer a-f pn total-pages date-str time-str datetime-str
            ]
        ]

        reset-font
        pages
    ] ; generate

    render-page: func [
        "Render a page draw block at given zoom percent (100 = native size)"
        page-block [block!] zoom [integer!]
        /local z sz composed
    ][
        z: zoom / 100.0
        sz: as-pair to integer! (page-width * z) to integer! (page-height * z)
        composed: compose/deep [scale (z) (z) (page-block)]
        draw sz composed
    ]

    get-page-width: does [page-width]
    get-page-height: does [page-height]

    show-viewer: func [
        "Display rendered pages in a viewer window with navigation and zoom"
        page-obj [object!] "needed for pdf generation"
        rendered [block!] "Block of image! (one per page, from render-page)"
        window-title [string!] "Window title"
        popup-fn [function! none!] "func [type [lit-word!] id [integer!] text [string!]]"
        /fit-width "Start in fit-width mode (default: full/proportional view)"
        /local current-page current-img fit-width? scroll-y toolbar-h
               popup-handler hovered-hs hint-active hint-start
               sv-page-width sv-page-height sv-page-hotspots
               screen-to-page hit-test scale-view update-buttons showpage
               display-title
               win btn-first btn-prev btn-next btn-last page-label fit-cb
               clip-f img-f p parentsize vp-w vp-h iw ih
               display-w display-h max-scroll delta page-pos new-hs hs pn
    ][
        current-page: 1
        current-img: none
        fit-width?: fit-width          ; seeded by the /fit-width refine (default full view)
        scroll-y: 0
        toolbar-h: 50
        popup-handler: :popup-fn
        ; window title shows the page size; the saved PDF keeps the clean name
        display-title: rejoin [window-title "  (" page-width " x " page-height ")"]
        hovered-hs: none
        hint-active: false
        hint-start: now/time/precise

        sv-page-width: page-width
        sv-page-height: page-height
        sv-page-hotspots: copy page-hotspots
        forall sv-page-hotspots [
            change/only sv-page-hotspots either first sv-page-hotspots [copy first sv-page-hotspots][none]
        ]
        sv-page-hotspots: head sv-page-hotspots

        screen-to-page: func [
            sx [number!] sy [number!] /local pw ph
        ][
            unless img-f/size [return none]
            pw: img-f/size/x
            ph: img-f/size/y
            if any [pw <= 0 ph <= 0][return none]
            as-pair
                to integer! sx * sv-page-width / pw
                to integer! sy * sv-page-height / ph
        ]

        hit-test: func [
            page-pos [pair!] /local hs hotspot
        ][
            unless all [sv-page-hotspots current-page <= length? sv-page-hotspots][return none]
            hs: pick sv-page-hotspots current-page
            unless hs [return none]
            foreach hotspot hs [
                if all [
                    page-pos/x >= hotspot/x  page-pos/x <= (hotspot/x + hotspot/w)
                    page-pos/y >= hotspot/y  page-pos/y <= (hotspot/y + hotspot/h)
                ][
                    return hotspot
                ]
            ]
            none
        ]

        scale-view: does [
            unless current-img [exit]
            parentsize: clip-f/parent/size
            vp-w: parentsize/x - 18
            vp-h: parentsize/y - toolbar-h - 30
            if any [vp-w < 50 vp-h < 50][exit]
            clip-f/size: as-pair vp-w vp-h
            iw: current-img/size/x
            ih: current-img/size/y
            img-f/image: current-img
            either fit-width? [
                display-w: vp-w
                display-h: to integer! vp-w * ih / iw
                max-scroll: max 0 display-h - vp-h
                scroll-y: max 0 min scroll-y max-scroll
                img-f/size: as-pair display-w display-h
                img-f/offset: as-pair 0 (0 - scroll-y)
            ][
                either (iw / ih) > (vp-w / vp-h) [
                    img-f/size: as-pair vp-w to integer! vp-w * ih / iw
                ][
                    img-f/size: as-pair to integer! vp-h * iw / ih  vp-h
                ]
                img-f/offset: as-pair to integer! (vp-w - img-f/size/x) / 2  0
                scroll-y: 0
            ]
        ]

        update-buttons: does [
            btn-first/enabled?: current-page > 1
            btn-prev/enabled?: current-page > 1
            btn-next/enabled?: current-page < length? rendered
            btn-last/enabled?: current-page < length? rendered
            page-label/text: rejoin ["Page " current-page " / " length? rendered]
        ]

        showpage: does [
            if any [empty? rendered current-page < 1 current-page > length? rendered] [exit]
            current-img: pick rendered current-page
            scroll-y: 0
            hovered-hs: none
            hint-active: false
            update-buttons
            do [scale-view]
        ]

        win: layout/flags  [
            title display-title
            size 800x600
            backdrop 230.230.230
            on-key [
                case [
                    all [event/ctrl? event/key = 'left]  [current-page: 1 showpage]
                    all [event/ctrl? event/key = 'right] [current-page: length? rendered showpage]
                    event/key = 'left  [if current-page > 1 [current-page: current-page - 1 showpage]]
                    event/key = 'right [if current-page < length? rendered [current-page: current-page + 1 showpage]]
                    all [fit-width? event/key = 'up] [
                        scroll-y: max 0 scroll-y - 40
                        do [scale-view]
                    ]
                    all [fit-width? event/key = 'down] [
                        scroll-y: scroll-y + 40
                        do [scale-view]
                    ]
                ]
            ]
            p: panel white 100x50 [
                across
                btn-first: button "<<"  [current-page: 1 showpage]
                btn-prev: button "<"  [if current-page > 1 [current-page: current-page - 1 showpage]]
                page-label: text  "" center
                btn-next: button ">" [if current-page < length? rendered [current-page: current-page + 1 showpage]]
                btn-last: button ">>" [current-page: length? rendered showpage]
                btn-pdf: button "Save PDF" [
                    dir: request-dir/title/dir rejoin ["Where to store " window-title ".pdf  ?"] %./pdf-reports/
                    if dir [
                        file: to-file rejoin [dir safe-file-stem window-title ".pdf"]
                        replace/all file " " ""
                        report-pdf/generate page-obj to-file file 
                        alert rejoin ["Success" newline file newline " saved !" newline ""]
                    ]
                ]
                btn-show-pdf: button "Show PDF" [
                        file: to file! rejoin ["." safe-file-stem window-title ".pdf"]
                        replace/all file " " ""
                        report-pdf/generate page-obj file 
                        browse  file
                        wait 3
                        delete file
                ]
                pad 10x0
                fit-cb: check "Fit Width" fit-width? [
                    fit-width?: fit-cb/data
                    scroll-y: 0
                    do [scale-view]
                ]
            ] react [face/size: as-pair (face/parent/size/x - 18) toolbar-h]
            return

            clip-f: panel  600x800 [
                img-f: image white
                    all-over
                    rate 1
                    on-over [
                        page-pos: screen-to-page event/offset/x event/offset/y
                        new-hs: either page-pos [hit-test page-pos][none]
                        either new-hs [
                            unless all [hovered-hs new-hs/hint-id = hovered-hs/hint-id][
                                hovered-hs: new-hs
                                hint-active: false
                                hint-start: now/time/precise
                            ]
                        ][
                            if hovered-hs [
                                hovered-hs: none
                                hint-active: false
                            ]
                        ]
                    ]
                    on-time [
                        if all [hovered-hs hovered-hs/hint-id not hint-active][
                            if (to integer! now/time/precise - hint-start) > hint-delay [
                                hint-active: true
                                if :popup-handler [
                                    popup-handler 'hint hovered-hs/hint-id hovered-hs/text
                                ]
                                hovered-hs: none
                                hint-active: false
                            ]
                        ]
                    ]
                    on-down [
                        if :popup-handler [
                            page-pos: screen-to-page event/offset/x event/offset/y
                            hs: hit-test page-pos
                            if all [hs hs/link-id][
                                popup-handler 'link hs/link-id hs/text
                            ]
                        ]
                    ]
                on-wheel [
                    delta: either event/picked [event/picked][0]
                    either fit-width? [
                        scroll-y: scroll-y - (30 * delta)
                        do [scale-view]
                    ][
                        either delta < 0 [
                            if current-page < length? rendered [current-page: current-page + 1 showpage]
                        ][
                            if current-page > 1 [current-page: current-page - 1 showpage]
                        ]
                    ]
                ]
                react [
                    face/size: face/parent/size - 18x30
                    do [scale-view]
                ]
            ] react [face/size: face/parent/size - 18x30]
        ] [resize modal]
        fit-width?: fit-cb/data          ; the checkbox drives the initial fit/full view
        do [showpage]
        view win
    ] ; show-viewer

] ; report-view

;set 'make-viewer make report-view []

show-report: func [
    "High-level entry point to generate and display a report using a fresh viewer instance. Takes the report block (parsed internally) and uses the paper size/orientation from its page description. Returns an empty string after the window is closed, or the problem message if the report is invalid (no window is opened)."
;    page-obj [object!] "Parsed page from parse-report"
    report [block!] "Report content in draw dialect"
    window-title [string!] "Window title"
    /popup popup-fn [function! none!] "func [type [word!] id [word! number!] text [string!]]"
    /fit-width "Start in fit-width mode (default: full/proportional view)"
    /local viewer pgs rendered p msg
][
    ; Validate first: return the problem message instead of opening a window.
    msg: validate-report report
    if msg <> "" [return msg]

    ; Use fresh instance to prevent state sharing/corruption
    viewer: make report-view []
    page-obj: parse-report report
    pgs: viewer/generate page-obj
    rendered: copy []
    foreach p pgs [
        append/only rendered viewer/render-page p 300
    ]
    either fit-width [
        viewer/show-viewer/fit-width page-obj rendered window-title :popup-fn
    ][
        viewer/show-viewer page-obj rendered window-title :popup-fn
    ]
    ""   ; success: the window was shown and closed
]

show-popup: function [ "Show a popup with styled content"
    title [string!] 
    content [block!] ; our report page format
    win-size [pair!]
][
    popup: make report-view [] ;necessary so we don't interfere with the main viewer
    popup/paper-format win-size
    popup/fontsize 12
    rendered: popup/generate parse-report content
    view/options/flags [
        title title
        box win-size draw rendered
        return
        button "OK" focus [unview] react [face/offset: face/parent/size - 88x30]
    ][size: win-size + 20x80][resize modal]
]
