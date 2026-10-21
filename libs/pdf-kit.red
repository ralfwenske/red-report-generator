Red [
    File: %pdf-kit.red
    Title: "Pure-Red PDF writer (text-native prototype)"
    Purpose: {
        Minimal PDF 1.4 writer implemented in pure Red - no external
        tools, no Ghostscript. Base-14 fonts with Adobe AFM metrics,
        explicit MediaBox, vector text, colors, rectangles, lines,
        JPEG image XObjects, multi-page documents and xref table.
    }
]

#include %pdf-fonts.red

pdf-kit: context [

    ;=== paper size (PostScript points) ===

    pw: 595
    ph: 842

    set-paper: func [w [number!] h [number!]][
        pw: w
        ph: h
    ]

    ;=== the 12 base-14 fonts (order matches pdf-fonts tables) ===

    font-names: [
        "Times-Roman" "Times-Bold" "Times-Italic" "Times-BoldItalic"
        "Helvetica" "Helvetica-Bold" "Helvetica-Oblique" "Helvetica-BoldOblique"
        "Courier" "Courier-Bold" "Courier-Oblique" "Courier-BoldOblique"
    ]

    ;=== named colors ===

    named-colors: [
        red 255.0.0 blue 0.0.255 green 0.128.0 white 255.255.255
        black 0.0.0 yellow 255.255.0 navy 0.0.128 sky 135.206.235
        gray 128.128.128 orange 255.165.0 purple 128.0.128
    ]

    ;=== number / color helpers ===

    num: func [v [number!]][
        form round/to (to float! v) 0.01
    ]

    rgb: func [c [tuple!] /local r g b][
        r: form round/to (c/1 / 255.0) 0.001
        g: form round/to (c/2 / 255.0) 0.001
        b: form round/to (c/3 / 255.0) 0.001
        rejoin [r " " g " " b]
    ]

    color: func [tok /local c][
        either tuple? tok [tok][select named-colors tok]
    ]

    ;=== text metrics: Adobe AFM widths, units of 1/1000 em ===

    text-width: func [font-no [integer!] size [number!] str [string!]
        /local tb w v code
    ][
        tb: pick pdf-fonts font-no
        w: 0
        foreach ch str [
            code: (to integer! ch) + 1
            v: pick tb code
            w: w + either integer? v [v][0]
        ]
        w * size / 1000.0
    ]

    ;=== hex-encode a string (byte-exact; avoids escaping issues) ===

    hex: func [str [string!] /local out c][
        out: copy ""
        foreach ch str [
            c: to integer! ch
            if c > 255 [c: 63]                        ;-- '?' for non-Latin1 (prototype)
            append out pick "0123456789ABCDEF" (to integer! (c / 16)) + 1
            append out pick "0123456789ABCDEF" (c % 16) + 1
        ]
        out
    ]

    ;=== page buffer ===

    new-page: func [][
        make object! [content: copy ""]
    ]

    emit: func [pg [object!] data [block!]][
        append pg/content rejoin data
        append pg/content lf
    ]

    ;=== text: baseline at (x, y), absolute positioning ===

    text: func [pg [object!] x [number!] y [number!] str [string!]
        font-no [integer!] size [number!] fg [tuple! none!]
    ][
        if empty? str [exit]
        emit pg [either fg [rgb fg]["0 0 0"] " rg"]
        emit pg [
            "BT /F" font-no " " (form size) " Tf "
            "1 0 0 1 " (num x) " " (num y) " Tm <" (hex str) "> Tj ET"
        ]
    ]

    ;=== text aligned within [x, x+width] ===

    text-align: func [pg [object!] x [number!] y [number!] str [string!]
        font-no [integer!] size [number!] fg [tuple! none!]
        al [string!] width [number!] /local tw ax
    ][
        tw: text-width font-no size str
        ax: case [
            al = "C" [x + ((width - tw) / 2.0)]
            al = "R" [x + width - tw]
            true [x]
        ]
        text pg ax y str font-no size fg
        tw
    ]

    ;=== shapes ===

    fill-rect: func [pg [object!] x [number!] y [number!] w [number!] h [number!] col [tuple!]][
        emit pg [rgb col " rg " (num x) " " (num y) " " (num w) " " (num h) " re f"]
    ]

    stroke-rect: func [pg [object!] x [number!] y [number!] w [number!] h [number!]
        col [tuple!] wd [number!]
    ][
        emit pg [rgb col " RG " (form wd) " w " (num x) " " (num y) " " (num w) " " (num h) " re S"]
    ]

    line: func [pg [object!] x1 [number!] y1 [number!] x2 [number!] y2 [number!]
        col [tuple!] wd [number!]
    ][
        emit pg [rgb col " RG " (form wd) " w " (num x1) " " (num y1)
                 " m " (num x2) " " (num y2) " l S"]
    ]

    ;=== JPEG image XObjects ===

    images: copy []
    img-tmp: 0

    embed-image-bytes: func [
        "Embed an in-memory image! as a JPEG XObject, with an optional alpha SMask; returns its key (or none)."
        img [image!]
        /check-alpha "Inspect image/argb for transparency (skip for formats without alpha, e.g. JPEG)"
        /local tmp jpg key argb a
    ][
        img-tmp: img-tmp + 1
        tmp: to file! rejoin [what-dir %.img-tmp- img-tmp ".jpg"]
        save/as tmp img 'jpeg
        jpg: read/binary tmp
        delete tmp
        ; JPEG has no alpha channel. Red keeps transparency in the image's
        ; 4-byte-per-pixel buffer (image/argb, byte order B G R A); the alpha byte is
        ; the 4th. It travels to the PDF as a grayscale /SMask so the image
        ; composites over any backdrop. A fully opaque alpha is dropped (no SMask).
        ; Scanning every image's ARGB buffer is expensive, so callers pass
        ; /check-alpha only for formats that can carry alpha.
        a: none
        if check-alpha [
            argb: attempt [img/argb]
            if argb [
                a: extract/index argb 4 4
                ; a fully opaque alpha needs no SMask
                if parse a [some #{FF} end][a: none]
            ]
        ]
        key: to word! rejoin ["Im" (to integer! ((length? images) / 5)) + 1]
        append images reduce [key img/size/x img/size/y jpg a]
        key
    ]

    embed-image: func [file [file!] /local img alpha-ext?][
        img: attempt [load file]
        unless img [
            print rejoin ["Warning: cannot load image " file]
            return none
        ]
        ; PNG/BMP/GIF may carry alpha; JPEG never does, so skip the ARGB scan.
        alpha-ext?: find [".png" ".bmp" ".gif" ".webp"] lowercase form suffix? file
        either alpha-ext? [embed-image-bytes/check-alpha img][embed-image-bytes img]
    ]

    embed-image-value: func [img [image!]][embed-image-bytes/check-alpha img]

    image-dims: func [key [word!] /local pos][
        pos: find images key
        either pos [reduce [pos/2 pos/3]][none]
    ]

    draw-image: func [pg [object!] x [number!] y [number!] w [number!] h [number!] key [word!]][
        emit pg ["q " (num w) " 0 0 " (num h) " " (num x) " " (num y) " cm /" key " Do Q"]
    ]

    ;=== document assembly ===

    save-pdf: func [file [file!] pages [block!]
        /local n m c0 i0 r0 f0 kids fonts-str imgs-str body out offs
        put-obj xref-off img-key img-w img-h img-bytes img-alpha content-len
        imgnums next-obj imgobj smobj smbody
        i j f g0 objnum off
    ][
        n: length? pages
        m: to integer! ((length? images) / 5)

        ;-- object numbering: 1 catalog, 2 pages tree,
        ;-- then page dicts, then content streams, then images (plus an
        ;-- alpha SMask object per transparent image), then resources,
        ;-- then the 12 base-14 font dicts
        c0: 3
        i0: c0 + n            ;-- first content stream object
        g0: i0 + n            ;-- first image XObject object
        imgnums: copy []
        next-obj: g0
        repeat j m [
            imgobj: next-obj
            next-obj: next-obj + 1
            smobj: none
            if pick images ((j - 1) * 5) + 5 [
                smobj: next-obj
                next-obj: next-obj + 1
            ]
            append imgnums reduce [imgobj smobj]
        ]
        r0: next-obj          ;-- resources object
        f0: r0 + 1            ;-- first font object

        out: make binary! 40000
        offs: copy []
        append out to binary! "%PDF-1.4"
        append out lf

        put-obj: func [out [binary!] offs [block!] num [integer!] body [string! binary!]][
            append offs reduce [num (length? out)]
            append out to binary! rejoin [num " 0 obj" lf]
            append out body
            append out to binary! rejoin [lf "endobj" lf]
        ]

        ;-- 1: catalog
        put-obj out offs 1 "<< /Type /Catalog /Pages 2 0 R >>"

        ;-- 2: pages tree
        kids: copy ""
        repeat i n [append kids rejoin [(c0 + i - 1) " 0 R "]]
        put-obj out offs 2 rejoin ["<< /Type /Pages /Kids [" kids "] /Count " n " >>"]

        ;-- page dicts (explicit MediaBox = same page on every platform)
        repeat i n [
            put-obj out offs (c0 + i - 1) rejoin [
                "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 " pw " " ph "]"
                " /Resources " r0 " 0 R /Contents " (i0 + i - 1) " 0 R >>"
            ]
        ]

        ;-- content streams
        repeat i n [
            content-len: length? pages/(i)/content
            put-obj out offs (i0 + i - 1) rejoin [
                "<< /Length " content-len " >>" lf "stream" lf
                pages/(i)/content lf "endstream"
            ]
        ]

        ;-- image XObjects (DCTDecode = raw JPEG bytes; optional /SMask for alpha)
        repeat j m [
            img-key: pick images ((j - 1) * 5) + 1
            img-w:   pick images ((j - 1) * 5) + 2
            img-h:   pick images ((j - 1) * 5) + 3
            img-bytes: pick images ((j - 1) * 5) + 4
            img-alpha: pick images ((j - 1) * 5) + 5
            imgobj: pick imgnums ((j - 1) * 2) + 1
            smobj:  pick imgnums ((j - 1) * 2) + 2
            body: make binary! 4096
            append body to binary! rejoin [
                "<< /Type /XObject /Subtype /Image /Width " img-w
                " /Height " img-h " /ColorSpace /DeviceRGB"
                " /BitsPerComponent 8 /Filter /DCTDecode"
                either smobj [rejoin [" /SMask " smobj " 0 R"]][""]
                " /Length " (length? img-bytes) " >>" lf "stream" lf
            ]
            append body img-bytes
            append body to binary! rejoin [lf "endstream"]
            put-obj out offs imgobj body
            if smobj [
                smbody: make binary! 4096
                append smbody to binary! rejoin [
                    "<< /Type /XObject /Subtype /Image /Width " img-w
                    " /Height " img-h " /ColorSpace /DeviceGray"
                    " /BitsPerComponent 8 /Length " (length? img-alpha) " >>" lf "stream" lf
                ]
                append smbody img-alpha
                append smbody to binary! rejoin [lf "endstream"]
                put-obj out offs smobj smbody
            ]
        ]

        ;-- resources: all 12 fonts + all embedded images
        fonts-str: copy ""
        repeat f 12 [append fonts-str rejoin ["/F" f " " (f0 + f - 1) " 0 R "]]
        imgs-str: copy ""
        repeat j m [
            append imgs-str rejoin [
                "/" (pick images ((j - 1) * 5) + 1) " " (pick imgnums ((j - 1) * 2) + 1) " 0 R "
            ]
        ]
        put-obj out offs r0 rejoin ["<< /Font << " fonts-str ">> /XObject << " imgs-str ">> >>"]

        ;-- base-14 font dicts (never embedded; viewers have them)
        repeat f 12 [
            put-obj out offs (f0 + f - 1) rejoin [
                "<< /Type /Font /Subtype /Type1 /BaseFont /" (pick font-names f)
                " /Encoding /WinAnsiEncoding >>"
            ]
        ]

        ;-- xref table (byte-exact offsets)
        xref-off: length? out
        append out to binary! rejoin ["xref" lf "0 " (to integer! ((length? offs) / 2)) + 1 lf]
        append out to binary! rejoin ["0000000000 65535 f " lf]
        foreach [objnum off] offs [
            append out to binary! rejoin [pad10 off " 00000 n " lf]
        ]
        append out to binary! rejoin [
            "trailer" lf "<< /Size " (to integer! ((length? offs) / 2)) + 1 " /Root 1 0 R >>" lf
            "startxref" lf xref-off lf "%%EOF" lf
        ]

        write/binary file out
        length? out
    ]

    pad10: func [v [integer!] /local s][
        s: form v
        while [10 > length? s][insert s "0"]
        s
    ]
]
