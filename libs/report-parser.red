Red [
    File: %report-parser.red
    Purpose: "Parse report-page dialect into structured data for rendering"
    Exports: [parse-report dump-report validate-report]
]

#include %report-styles.red

report-parser: context [

    ;--- Helpers ---------------------------------------------------------------

 is-style?: func [blk [block!]][
    ; Style blocks contain formatting directives (words, numbers, tuples)
    ; Data blocks contain strings or nested blocks
    not any [find blk string!  find blk block!]
]

parse-pairs: func [
    "Parse a line into value-style pairs; the inherited base plus a leading style-block style the line, per-value styles merge on top, and !X drops X from all higher levels"
    blk [block!] base [block!]
    /local result val sty eff
][
    result: copy []
    eff: base
    ; an empty line block is a blank line: treat it exactly like [""]
    if empty? blk [return reduce [reduce ["" copy eff]]]
    ; optional leading style block applies to every value on the line
    if all [not tail? blk block? blk/1 is-style? blk/1][
        eff: report-styles/merge-styles eff blk/1
        blk: next blk
    ]
    while [not tail? blk][
        val: blk/1
        sty: none
        blk: next blk
        if all [not tail? blk block? blk/1 is-style? blk/1][
            sty: blk/1
            blk: next blk
        ]
        append/only result reduce [val either sty [report-styles/merge-styles eff sty][copy eff]]
    ]
    result
]

known-keywords: [header body footer table image column pagebreak draw-bg draw]
paper-sizes:    [a4 letter legal a3 a5]
margin-sides:   [top bottom left right margin]

parse-margin-spec: func [
    "Parse a margin word like 'top-20 / 'right-10 / 'margin-20. Returns [side n] or none."
    d [word!]
    /local s side n
][
    s: form d
    either parse s [copy side to "-" "-" copy n to end][
        n: attempt [to integer! n]
        if all [n  find margin-sides to word! side][reduce [to word! side n]]
    ][
        none
    ]
]

parse-section: func [
    {Parse a block of items into lines or keyword objects.
     Uniform item grammar: [known-word args... [items]?]  |  [value [styles]? ...]}
    blk [block!]
    /base bs [block!]
    /local result pos val kw-type kw-args body inner cbs ta a col-img
][
    result: copy []
    pos: blk
    if none? bs [bs: copy []]

    while [not tail? pos][
        ;--- Paren expressions (safety net if not pre-composed) ---
        if paren? pos/1 [
            val: do pos/1
            if block? val [append result parse-section/base val bs]
            pos: next pos
            continue
        ]

        ;--- Keyword item: [known-word args... [items]?] ---
        if all [
            block? pos/1
            not empty? pos/1
            any-word? pos/1/1
            find known-keywords to word! pos/1/1
        ][
            kw-type: to word! pos/1/1
            kw-args: copy []
            body: copy []
            col-img: none
            inner: next pos/1
            ; COLUMN: optional "image [styles]" clause after the text args carries the styles
            ; for contained IMAGE rows; the last block is the items. Generic args (before the
            ; image marker) style text rows only.
            if kw-type = 'column [
                while [not tail? inner][
                    either all [any [word? inner/1 lit-word? inner/1]  (lowercase form inner/1) = "image"][
                        inner: next inner
                        if all [not tail? inner block? inner/1][
                            col-img: inner/1
                            inner: next inner
                        ]
                    ][
                        either paren? inner/1 [
                            val: do inner/1
                            either block? val [
                                body: parse-section/base val bs
                                inner: next inner
                                break
                            ][
                                append kw-args inner/1
                                inner: next inner
                            ]
                        ][
                            either block? inner/1 [
                                body: parse-section/base inner/1 bs
                                inner: next inner
                                break
                            ][
                                append kw-args inner/1
                                inner: next inner
                            ]
                        ]
                    ]
                ]
                append/only result object [type: kw-type args: kw-args img: col-img lines: body]
                pos: next pos
                continue
            ]
            ; DRAW-BG: optional integer pixel-density arg, then ONE raw draw block
            if kw-type = 'draw-bg [
                while [all [not tail? inner not block? inner/1 not paren? inner/1]][
                    append kw-args inner/1
                    inner: next inner
                ]
                if all [not tail? inner block? inner/1][body: copy inner/1]
                append/only result object [type: kw-type args: kw-args lines: body]
                pos: next pos
                continue
            ]
            ; DRAW: optional integer height arg, then ONE raw draw block (inline art)
            if kw-type = 'draw [
                while [all [not tail? inner not block? inner/1 not paren? inner/1]][
                    append kw-args inner/1
                    inner: next inner
                ]
                if all [not tail? inner block? inner/1][body: copy inner/1]
                append/only result object [type: kw-type args: kw-args img: none lines: body]
                pos: next pos
                continue
            ]
            ; args: values up to the first block or paren (the items block)
            while [all [not tail? inner not block? inner/1 not paren? inner/1]][
                append kw-args inner/1
                inner: next inner
            ]
            ; content base = inherited base merged with this item's style args;
            ; sections and TABLE thread their style args to their content
            cbs: bs
            switch kw-type [
                header [cbs: report-styles/merge-styles bs kw-args]
                body   [cbs: report-styles/merge-styles bs kw-args]
                footer [cbs: report-styles/merge-styles bs kw-args]
                table  [
                    ta: copy []
                    foreach a kw-args [
                        unless find ["BOX" "ALT"] uppercase copy form a [append ta a]
                    ]
                    cbs: report-styles/merge-styles bs ta
                ]
            ]
            ; optional items block (a paren yields items when it evaluates to a block)
            case [
                all [not tail? inner paren? inner/1][
                    val: do inner/1
                    if block? val [body: parse-section/base val cbs]
                ]
                all [not tail? inner block? inner/1][
                    either all [kw-type = 'image  not empty? inner/1  not block? inner/1/1][
                        ; IMAGE caption: a value-leading block is ONE [value [styles]] line
                        body: reduce [parse-pairs inner/1 cbs]
                    ][
                        body: parse-section/base inner/1 cbs
                    ]
                ]
            ]
            append/only result object [type: kw-type args: kw-args lines: body]
            pos: next pos
            continue
        ]

        ;--- Line block: [value [styles]? value [styles]? ...] ---
        if block? pos/1 [
            append/only result parse-pairs pos/1 bs
            pos: next pos
            continue
        ]

        ;--- Skip anything else ---
        pos: next pos
    ]
    result
]

    ;--- Top-level page parsing -----------------------------------------------

    set 'parse-report func [
        {Parse a report page into a structured object. A page is an optional paper clause
         (leading paper-size word, WxH pair, and/or landscape/portrait) followed by block
         items; the HEADER, BODY and FOOTER section items split into the section objects.
         BODY is required; HEADER and FOOTER are optional and may appear in any order.
         Default paper is a4 portrait.}
        page [block!]
        /local items h-args h-lines c-args c-lines f-args f-lines has-body bg-args bg-lines
               size-n orient-n clause pos d t-n b-n l-n r-n m-u ms n m-top m-bottom m-left m-right
    ][
        ;--- Paper clause: leading size/orientation/margin words or a WxH pair before the items ---
        size-n: 'a4
        orient-n: 'portrait
        t-n: b-n: l-n: r-n: m-u: none
        clause: copy []
        pos: page
        while [all [not tail? pos  any [word? pos/1  pair? pos/1]]][
            d: pos/1
            append/only clause d
            case [
                pair? d                          [size-n: d]
                all [word? d  find paper-sizes to word! d]   [size-n: to word! d]
                all [word? d  d = 'landscape]    [orient-n: 'landscape]
                all [word? d  d = 'portrait]     [orient-n: 'portrait]
                all [word? d  ms: parse-margin-spec d][
                    n: ms/2
                    switch ms/1 [
                        margin [m-u: n]          ; uniform base for all four
                        top    [t-n: n]         ; individual overrides, order-independent
                        bottom [b-n: n]
                        left   [l-n: n]
                        right  [r-n: n]
                    ]
                ]
                true                             []
            ]
            pos: next pos
        ]
        ; individual side always wins over margin-N; margin-N over the 50 default
        m-top:    any [t-n m-u 50]
        m-bottom: any [b-n m-u 50]
        m-left:   any [l-n m-u 50]
        m-right:  any [r-n m-u 50]

        h-args: h-lines: c-args: c-lines: f-args: f-lines: bg-args: bg-lines: copy []
        has-body: false

        items: parse-section/base pos report-styles/base-styles
        foreach it items [
            if all [object? it find [header body footer] it/type][
                switch it/type [
                    header [h-args: it/args  h-lines: it/lines]
                    body   [c-args: it/args  c-lines: it/lines  has-body: true]
                    footer [f-args: it/args  f-lines: it/lines]
                ]
            ]
            if all [object? it it/type = 'draw-bg][
                bg-args: it/args
                bg-lines: it/lines
            ]
        ]

        unless has-body [return none]

        object [
            paper:       reduce [size-n orient-n]
            paper-args:  clause
            margin:      object [top: m-top bottom: m-bottom left: m-left right: m-right]
            header:  object [args: h-args lines: h-lines]
            content: object [args: c-args lines: c-lines]
            footer:  object [args: f-args lines: f-lines]
            draw-bg: object [args: bg-args lines: bg-lines]
        ]
    ]

    ;--- Validation ------------------------------------------------------------

    ; style-word vocabulary is defined once in report-styles (style-words)

    style-atom-ok?: func [
        {Is a single style atom allowed? Family words (s/m/ss), any style word with
         an optional -N size suffix (e.g. i-8, m-10, ss-12), format/alignment words,
         link-N/hint-N, widths and colours are allowed.}
        s [any-type!]
        /local ss
    ][
        case [
            tuple? s [true]
            issue? s [true]          ; #Npx / #Nch
            number? s [true]         ; integer width or float number-format
            word? s [
                any [
                    find report-styles/style-words s
                    not none? report-styles/family-of s
                    all [
                        ss: report-styles/size-suffix s
                        any [
                            find report-styles/style-words ss/1
                            not none? report-styles/family-of ss/1
                        ]
                    ]
                    all [(length? form s) >= 6 (copy/part form s 5) = "link-"]
                    all [(length? form s) >= 6 (copy/part form s 5) = "hint-"]
                    tuple? attempt [get s]    ; colour word
                ]
            ]
            true [false]
        ]
    ]

    style-word-ok?: func [
        {Is an atom allowed in a style block? As style-atom-ok?, plus !X negations.}
        s [any-type!]
    ][
        either all [word? s (length? form s) >= 2 (first form s) = #"!"][
            style-atom-ok? to word! copy skip form s 1
        ][
            style-atom-ok? s
        ]
    ]

    style-hint: func [
        {Suggestion for a mistyped style word: family/style word + digits without the
         hyphen, e.g. s16 -> 's-16'. Returns " (did you mean 's-16'?)" or "".}
        s [any-type!]
        /local f i prefix num pw c ok
    ][
        if not word? s [return ""]
        f: form s
        i: 1
        while [all [i <= length? f not all [f/:i >= #"0" f/:i <= #"9"]]][i: i + 1]
        if any [i > length? f i = 1][return ""]
        prefix: copy/part f (i - 1)
        num: copy skip f (i - 1)
        ok: true
        foreach c num [if not all [c >= #"0" c <= #"9"][ok: false break]]
        unless ok [return ""]
        pw: attempt [to word! prefix]
        unless pw [return ""]
        unless any [find report-styles/style-words pw  not none? report-styles/family-of pw][return ""]
        rejoin [" (did you mean '" prefix "-" num "'?)"]
    ]

    check-line-styles: func [
        "Validate the style blocks of a parsed text line (block of [value styles] pairs). Returns a message or none."
        sec-name [string!] i [integer!] ln [block!]
        /local pair
    ][
        foreach pair ln [
            if all [(length? pair) >= 2 block? pair/2][
                foreach s pair/2 [
                    unless style-word-ok? s [
                        return rejoin [sec-name " line " i ": unknown style word '" mold s "'" style-hint s]
                    ]
                ]
            ]
        ]
        none
    ]

    bad-negation: func [
        {First !X anywhere in the page whose X is not a known style word, or none.
         Needed because merge-styles consumes !X before the merged-style check sees it.}
        blk [block!]
        /local v f
    ][
        foreach v blk [
            either block? v [
                if msg: bad-negation v [return msg]
            ][
                if all [word? v (length? f: form v) >= 2 (first f) = #"!"][
                    unless style-atom-ok? to word! copy skip f 1 [return v]
                ]
            ]
        ]
        none
    ]

    page-problem: func [
        {First obvious structural problem in a raw page block, or none. Cheap pre-check
         so validate-report can explain mistakes (unknown keyword/paper directive,
         bare words) before parse-report, which assumes validated input.}
        page [block!]
        /local pos d w
    ][
        ; leading paper clause: words and/or a WxH pair
        pos: page
        while [all [not tail? pos any [word? pos/1 pair? pos/1]]][
            d: pos/1
            if word? d [
                w: to word! d
                case [
                    find paper-sizes w []
                    find [landscape portrait] w []
                    parse-margin-spec d []
                    find known-keywords w [
                        return rejoin ["Section keyword '" mold d "' must be written as a block item, e.g. [" form w " [...]]"]
                    ]
                    true [
                        return rejoin [
                            "Unknown word '" mold d
                            "' (expected a paper size a4/a5/a3/letter/legal, a WxH pair, landscape/portrait, a margin like margin-20, or a block item like [BODY [...]])"
                        ]
                    ]
                ]
            ]
            pos: next pos
        ]
        ; items: every one should be a block (a paren is allowed as a computed block)
        while [not tail? pos][
            d: pos/1
            case [
                word? d [
                    return rejoin ["Bare word '" mold d "' between items; each item is written as a block, e.g. [BODY [...]]"]
                ]
                all [block? d not empty? d word? d/1 not find known-keywords to word! d/1][
                    return rejoin [
                        "Unknown section keyword '" mold d/1 "' (expected one of " mold known-keywords ")"
                    ]
                ]
            ]
            pos: next pos
        ]
        none
    ]

    set 'validate-report func [
        {Validate a report page description. Returns "" if OK, else a message describing the first problem.}
        page [block!]
        /local err pg msg ln i row a bg parsed
    ][
        ;--- Cheap structural pre-check (catches unknown keywords/directives) ---
        msg: page-problem page
        if msg [return msg]
        ;--- Negations are consumed by merge-styles, so check the raw page for them ---
        a: bad-negation page
        if a [return rejoin ["unknown style negation '" mold a "'" style-hint a]]

        ;--- Parse under try: catches runtime errors in parens etc. ---
        err: try [pg: parse-report page]
        if error? err [
            return rejoin [
                err/type " error: " err/id
                either err/near [rejoin [" near " mold err/near]][""]
            ]
        ]
        if not object? pg [
            return "BODY section is missing; a report needs a [BODY [...]] item"
        ]

        ;--- Paper clause ---
        foreach d pg/paper-args [
            unless any [
                pair? d
                all [word? d find paper-sizes to word! d]
                all [word? d find [landscape portrait] d]
                all [word? d parse-margin-spec d]
            ][
                return rejoin ["Paper directive '" mold d "' is not a size (a4 letter legal a3 a5), a WxH pair, landscape/portrait, or a margin (top/bottom/left/right|margin-N)"]
            ]
        ]

        ;--- DRAW-BG (optional): one draw block, optional integer pixel-density arg ---
        bg: pg/draw-bg
        unless all [object? bg block? bg/lines][return "DRAW-BG: malformed"]
        if not empty? bg/lines [
            if (length? bg/args) > 1 [return "DRAW-BG takes at most one density number"]
            if all [not empty? bg/args not integer? bg/args/1][return "DRAW-BG density must be an integer"]
            if all [not empty? bg/args bg/args/1 < 1][return "DRAW-BG density must be 1 or more"]
        ]

        ;--- Structural checks per section ---
        foreach [sec-name sec] reduce [
            "HEADER" pg/header
            "BODY" pg/content
            "FOOTER" pg/footer
        ][
            unless all [object? sec block? sec/lines][
                return rejoin [sec-name ": section missing or malformed"]
            ]
            foreach a sec/args [
                unless style-word-ok? a [
                    return rejoin [sec-name " args: unknown style word '" mold a "'" style-hint a]
                ]
            ]
            i: 0
            foreach ln sec/lines [
                i: i + 1
                if block? ln [
                    msg: check-line-styles sec-name i ln
                    if msg [return msg]
                    continue
                ]
                unless object? ln [
                    return rejoin [sec-name " line " i ": expected a text line or keyword, got " mold ln]
                ]
                either find [header body footer] ln/type [
                        return rejoin [sec-name " line " i ": '" ln/type "' is a section keyword; sections are only allowed at the top level"]
                    ][
                        unless find [table image column pagebreak draw] ln/type [
                            return rejoin [sec-name " line " i ": unknown keyword '" ln/type]
                        ]
                    ]
                    switch ln/type [
                        image [
                            if (length? ln/args) < 1 [
                                return rejoin [sec-name " line " i ": IMAGE needs a file, e.g. [IMAGE %file.jpg] or [IMAGE 60 %file.jpg]"]
                            ]
                            either (length? ln/args) >= 2 [
                                unless any [number? ln/args/1 issue? ln/args/1] [
                                    return rejoin [sec-name " line " i ": IMAGE width must be a number or #px/#ch tag, got " mold ln/args/1]
                                ]
                                unless any [file? ln/args/2 string? ln/args/2] [
                                    return rejoin [sec-name " line " i ": IMAGE file must be a file path, got " mold ln/args/2]
                                ]
                            ][
                                unless any [file? ln/args/1 string? ln/args/1] [
                                    return rejoin [sec-name " line " i ": IMAGE needs a file path, got " mold ln/args/1]
                                ]
                            ]
                            if (length? ln/args) > 2 [
                                return rejoin [sec-name " line " i ": IMAGE takes at most (width file); put caption and its styles in a nested block, e.g. [IMAGE 60 %f [Caption [shadow 3 silver]]]"]
                            ]
                            if (length? ln/lines) > 1 [
                                return rejoin [sec-name " line " i ": IMAGE takes at most one caption line"]
                            ]
                            if not empty? ln/lines [
                                cap-line: ln/lines/1
                                unless all [block? cap-line not empty? cap-line block? cap-line/1 not empty? cap-line/1] [
                                    return rejoin [sec-name " line " i ": IMAGE caption must be a line like [Caption [styles]], got " mold cap-line]
                                ]
                                unless string? cap-line/1/1 [
                                    return rejoin [sec-name " line " i ": IMAGE caption value must be a string, got " mold cap-line/1/1]
                                ]
                                msg: check-line-styles sec-name i cap-line
                                if msg [return msg]
                            ]
                        ]
                        column [
                            if empty? ln/lines [
                                return rejoin [sec-name " line " i ": COLUMN has no data block"]
                            ]
                            wg: 0
                            foreach a ln/args [
                                either any [number? a issue? a a = 'auto][
                                    wg: wg + 1
                                    if wg > 2 [
                                        return rejoin [sec-name " line " i ": COLUMN takes at most (width gap), got " mold ln/args]
                                    ]
                                ][
                                    unless style-word-ok? a [
                                        return rejoin [sec-name " line " i ": COLUMN arg must be a number, #px/#ch tag, 'auto or a style word (s/ss/m, b u i, h1-h3, -N sizes, link-N), got " mold a]
                                    ]
                                ]
                            ]
                            if ln/img [
                                foreach st ln/img [
                                    unless style-word-ok? st [
                                        return rejoin [sec-name " line " i ": COLUMN image style must be shadow/border, an inset number, a width, a color, or a caption style (s/ss/m, b i u, h1-h3, -N sizes, link-N), got " mold st]
                                    ]
                                ]
                            ]
                            foreach r ln/lines [
                                case [
                                    block? r [
                                        msg: check-line-styles sec-name i r
                                        if msg [return msg]
                                    ]
                                    all [object? r r/type = 'image][
                                        if all [block? r/lines not empty? r/lines][
                                            msg: check-line-styles sec-name i r/lines/1
                                            if msg [return msg]
                                        ]
                                    ]
                                    all [object? r r/type = 'pagebreak][true]
                                    true [
                                        return rejoin [sec-name " line " i ": COLUMN rows may be text or IMAGE, got " mold r]
                                    ]
                                ]
                            ]
                        ]
                        table [
                            if empty? ln/lines [
                                return rejoin [sec-name " line " i ": TABLE has no data block"]
                            ]
                            row: 0
                            foreach r ln/lines [
                                row: row + 1
                                unless any [block? r all [object? r r/type = 'pagebreak]] [
                                    return rejoin [sec-name " line " i ": TABLE row " row " must be a line block, got " mold r]
                                ]
                                if block? r [
                                    msg: check-line-styles sec-name i r
                                    if msg [return msg]
                                ]
                            ]
                        ]
                        pagebreak [true] ; any args acceptable
                        draw [
                            unless sec-name = "BODY" [
                                return rejoin [sec-name " line " i ": DRAW is only supported inside BODY"]
                            ]
                            if (length? ln/args) > 1 [
                                return rejoin [sec-name " line " i ": DRAW takes at most one height (integer), got " mold ln/args]
                            ]
                            if all [not empty? ln/args not integer? ln/args/1] [
                                return rejoin [sec-name " line " i ": DRAW height must be an integer, got " mold ln/args/1]
                            ]
                            if all [not empty? ln/args ln/args/1 < 0] [
                                return rejoin [sec-name " line " i ": DRAW height must be 0 or more"]
                            ]
                            if empty? ln/lines [
                                return rejoin [sec-name " line " i ": DRAW needs a draw block, e.g. [DRAW 20 [box 0x0 40x20]]"]
                            ]
                            parsed: report-styles/draw-parse ln/lines
                            if all [not empty? parsed  parsed/1 = 'error][
                                return rejoin [sec-name " line " i ": DRAW: unsupported draw command '" mold parsed/2 "' (see 'Advanced usage - raw draw')"]
                            ]
                            unless report-styles/draw-args-ok? ln/lines [
                                return rejoin [sec-name " line " i ": DRAW: a command is missing its arguments"]
                            ]
                            if all [empty? ln/args  not report-styles/draw-ops-height ln/lines 0] [
                                return rejoin [sec-name " line " i ": DRAW has no measurable height below its cursor; add an explicit height, e.g. [DRAW 20 [...]]"]
                            ]
                        ]
                    ]
            ]
        ]
        ""
    ]

    ;--- Debug dump ------------------------------------------------------------

    set 'dump-report func [
        "Print parsed page structure for inspection"
        pg [object!]
        /local line
    ][
        print ["  paper:" mold pg/paper "  args:" mold pg/paper-args]
        print "=== HEADER ==="
        print ["  args:" mold pg/header/args]
        foreach line pg/header/lines [
            print ["  LINE:" mold line]
        ]

        print "^/=== BODY ==="
        print ["  args:" mold pg/content/args]
        foreach line pg/content/lines [
            either object? line [
                print ["  " uppercase form line/type "args:" mold line/args]
                foreach row line/lines [
                    either all [object? row row/type = 'pagebreak][
                        print ["    PAGEBREAK" either empty? row/args [""][" args:" mold row/args]]
                    ][
                        print ["    " mold row]
                    ]
                ]
            ][
                print ["  TEXT:" mold line]
            ]
        ]

        print "^/=== FOOTER ==="
        print ["  args:" mold pg/footer/args]
        foreach line pg/footer/lines [
            print ["  LINE:" mold line]
        ]
    ]

] ; report-parser context

