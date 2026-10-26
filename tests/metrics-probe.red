Red [
    Title:   "Font metrics probe"
    Purpose: {Measure the View's OS-font metrics against the PDF's Base-14 AFM
              metrics and print the per-platform parity constants. Run with
              red-view (needs size-text and draw):}
    Usage:   {red-view tests/metrics-probe.red}
    Needs:   'View
    Tabs:    4
]

; This is a development/calibration tool, not part of tests/check.red.
; It writes tests/metrics-probe.txt next to this script.

#include %../libs/report-view.red

rv: make report-view []

probe-dir: what-dir
out-file: to-file rejoin [probe-dir "metrics-probe.txt"]

out: copy ""
emit: func [s [string!]][
    append out s
    append out newline
    print s
]

; Bottom-most non-white pixel of a drawn "H" at a known line-box top (60).
; The bottom of "H" is the baseline, so ascent = baseline - 60.
measure-ascent: func [
    fnt
    /local img w h y x p base found
][
    w: 256  h: 160                       ; width divisible by 4 (Red stride)
    img: make image! reduce [as-pair w h white]
    unless attempt [draw img compose [font (fnt) pen black text 20x60 "H"]] [
        return none
    ]
    base: none
    y: 120
    while [y >= 45][
        x: 10
        found: false
        while [x < 80][
            p: pick img as-pair x y
            if any [p/1 < 250  p/2 < 250  p/3 < 250][
                found: true
                break
            ]
            x: x + 1
        ]
        if found [
            base: y
            break
        ]
        y: y - 1
    ]
    either base [base - 60][none]
]

ref: report-styles/alphabet
sizes: [8 9 10 12 14 18 24]
families: [[[s] "serif"] [[ss] "sans"] [[m] "mono"]]
weights: [[[] "regular"] [[b] "bold"] [[i] "italic"] [[b i] "bold-italic"]]

emit rejoin ["system/platform: " (form system/platform)
             "   normalized: " (form report-styles/platform)]
emit rejoin ["system/version: " (form system/version)]
emit rejoin ["view-width-factor: " (form report-styles/view-width-factor)]
emit "family   weight        size  view_w  pdf_w0  font_ratio  view_h  line_ratio  view_a  ascent_frac"

foreach f families [
    fam-styles: f/1
    fam-name: f/2
    foreach w weights [
        weight: w/1
        weight-name: w/2
        styles: copy fam-styles
        append styles weight
        foreach sz sizes [
            fnt: rv/build-font styles sz
            mf: make face! [size: 1000x100 font: fnt]
            view-w: either fam-name = "mono" [
                (length? ref) * (to integer! first size-text/with mf "M")
            ][
                to integer! first size-text/with mf ref
            ]
            view-h: to integer! second size-text/with mf "hg"
            view-a: measure-ascent fnt
            ascent-src: "drawn"
            unless view-a [
                view-a: to integer! round (view-h * report-styles/box-ascent-frac styles)
                ascent-src: "frac"
            ]
            fno: report-pdf/font-for-styles styles
            pdf-w0: pdf-kit/text-width fno (to float! sz) ref
            font-ratio: view-w * 1.0 / pdf-w0
            line-ratio: view-h * 1.0 / sz
            ascent-frac: either view-h > 0 [view-a * 1.0 / view-h][0.0]

            emit rejoin [
                pad fam-name 8 " "
                pad weight-name 12 " "
                pad form sz 4 "  "
                pad form view-w 6 "  "
                pad form round/to pdf-w0 0.01 8 "  "
                pad form round/to font-ratio 0.0001 10 "  "
                pad form view-h 6 "  "
                pad form round/to line-ratio 0.0001 10 "  "
                pad form view-a 6 "  "
                form round/to ascent-frac 0.0001
                "  (" ascent-src ")"
            ]
        ]
    ]
]

; Ready-to-paste summary from the 12 pt regular rows.
emit ""
emit "12 pt regular summary (family: font_scale line_scale ascent_frac)"
foreach f families [
    fam-styles: f/1
    fam-name: f/2
    styles: copy fam-styles
    fnt: rv/build-font styles 12
    mf: make face! [size: 1000x100 font: fnt]
    view-w: either fam-name = "mono" [
        (length? ref) * (to integer! first size-text/with mf "M")
    ][
        to integer! first size-text/with mf ref
    ]
    view-h: to integer! second size-text/with mf "hg"
    view-a: measure-ascent fnt
    unless view-a [view-a: to integer! round (view-h * report-styles/box-ascent-frac styles)]
    fno: report-pdf/font-for-styles styles
    pdf-w0: pdf-kit/text-width fno 12.0 ref
    eff: either find f/1 'm [1.0][report-styles/view-width-factor]
    emit rejoin [
        pad fam-name 6 ": "
        "font_scale=" form round/to (view-w * 1.0 / pdf-w0) 0.0001
        "  effective=" form round/to ((view-w * eff) / pdf-w0) 0.0001
        "  line_scale=" form round/to (view-h * 1.0 / 12) 0.0001
        "  ascent_frac=" form round/to (view-a * 1.0 / view-h) 0.0001
    ]
]

; Mixed reference matching the 015 body (lower/upper/digits/spaces).
ref2: "abcdefghijkl mnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890"
emit ""
emit "Mixed 015-like reference at 12 pt (family: view_w pdf_w ratio)"
foreach f families [
    fam-styles: f/1
    fam-name: f/2
    styles: copy fam-styles
    fnt: rv/build-font styles 12
    mf: make face! [size: 1000x100 font: fnt]
    view-w2: either fam-name = "mono" [
        (length? ref2) * (to integer! first size-text/with mf "M")
    ][
        to integer! first size-text/with mf ref2
    ]
    fno: report-pdf/font-for-styles styles
    pdf-w2: pdf-kit/text-width fno 12.0 ref2
    emit rejoin [
        pad fam-name 6 ": view=" form view-w2
        "  pdf=" form round/to pdf-w2 0.01
        "  ratio=" form round/to (view-w2 * 1.0 / pdf-w2) 0.0001
    ]
]

; Final comparison with the profile constants currently in the libraries.
; Use report-view/view-metrics, not raw size-text, because the View now adopts
; the PDF's per-size line box for layout (so h/a should match exactly).
emit ""
emit "Final PDF metrics vs View (current profile constants)"
emit "family  level  size  d_width  d_height  d_ascent"
levels: [[[] "body"] [[h3] "h3"] [[h2] "h2"] [[h1] "h1"]]
foreach f families [
    fam-styles: f/1
    fam-name: f/2
    foreach lv levels [
        styles: copy fam-styles
        append styles lv/1
        sz: report-styles/font-size-for styles
        fnt: rv/build-font styles sz
        mf: make face! [size: 1000x100 font: fnt]
        vm: rv/view-metrics ref styles
        pm: report-pdf/pdf-metrics ref styles
        emit rejoin [
            pad fam-name 8 " "
            pad lv/2 6 " "
            pad form sz 4 "  "
            pad form round/to (pm/1 - vm/1) 0.01 8 "  "
            pad form (pm/2 - vm/2) 9 "  "
            form (pm/3 - vm/3)
        ]
    ]
]

; 010-hello lists its own source with m/9 (normalized to m-9 by the parser);
; its line step is line-box + gap.
emit ""
emit "010-hello source listing (m/9)"
styles: [m-9]
sz: report-styles/font-size-for styles
fnt: rv/build-font styles sz
mf: make face! [size: 1000x100 font: fnt]
native-h: to integer! second size-text/with mf "hg"
vm: rv/view-metrics ref styles
pm: report-pdf/pdf-metrics ref styles
emit rejoin ["view  : w=" form vm/1 "  h=" form vm/2 "  a=" form vm/3
             "  step=" form (vm/2 + report-styles/line-gap-px)]
emit rejoin ["native: h=" form native-h "  (raw size-text line box)"]
emit rejoin ["pdf   : w=" form round/to pm/1 0.01 "  h=" form pm/2 "  a=" form pm/3
             "  step=" form (pm/2 + report-styles/line-gap-px)]
emit rejoin ["delta : w=" form round/to (pm/1 - vm/1) 0.01
             "  h=" form (pm/2 - vm/2) "  a=" form (pm/3 - vm/3)]

emit ""
emit rejoin ["wrote " (form out-file)]
write out-file out
quit/return 0