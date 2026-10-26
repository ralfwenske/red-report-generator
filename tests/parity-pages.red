Red [
    Title:   "View/PDF page-count parity probe"
    Purpose: {Load one sample, render it with report-view and report-pdf, and
              report both page counts. Run with red-view (needs size-text/draw).}
    Usage:   {red-view tests/parity-pages.red 010-hello.red [--render] [--zoom 100] [--keep]}
    Needs:   'View
    Tabs:    4
]

; Dev tool, not part of tests/check.red. Writes tests/parity-<sample>.txt
; (or tests/parity-<sample>-error.txt) and quits.

#include %../libs/report-view.red
change-dir %../
root: what-dir

args: any [system/options/args []]
render?: not none? find args "--render"
keep?: not none? find args "--keep"
zoom: 300
if zi: find args "--zoom" [zoom: to integer! pick args (index? zi) + 1]
sample: either empty? args [%010-hello.red][to-file first args]
stem: replace form sample ".red" ""
res-file: to-file rejoin [root "tests/parity-" stem ".txt"]
err-file: to-file rejoin [root "tests/parity-" stem "-error.txt"]
render-note: ""

show-report: func [
    report [block!] title [string!]
    /popup popup-fn
    /fit-width
][captured-report: report  ""]
alert: func [msg [any-type!]][]
result: ""

err: try [
    path: to-file rejoin ["samples/" sample]
    blk: load path
    change-dir first split-path clean-path path

    start: 1
    if all [not empty? blk  word? blk/1  blk/1 = 'Red  block? blk/2][start: 3]

    idx: none
    repeat i length? blk [
        if all [word? blk/:i  blk/:i = 'show-report][idx: i]
    ]
    suffix-at: idx
    if all [idx  idx > 1  (type? blk/(idx - 1)) = set-word!][suffix-at: idx - 1]

    prefix: copy []
    skip-next: false
    repeat i (either suffix-at [suffix-at - 1][length? blk]) [
        if i < start [continue]
        if skip-next [skip-next: false  continue]
        e: blk/:i
        if issue? e [skip-next: true  continue]      ; #include + its file
        append/only prefix e
    ]
    do prefix

    captured-report: none
    either suffix-at [
        do copy at blk suffix-at
    ][
        captured-report: get/any 'report
    ]
    unless block? captured-report [cause-error 'user 'message "no report block"]

    pg: parse-report captured-report

    ; View page count (keep cwd in samples/ for relative image paths)
    rv: make report-view []
    view-pages: rv/generate pg
    view-n: length? view-pages
    if all [render? not empty? view-pages][
        t0: now/time/precise
        img: rv/render-page pick view-pages 1 zoom
        t1: now/time/precise
        render-note: rejoin ["  render" form zoom "=" form (t1 - t0)]
        save/as to-file rejoin [root "tests/render-" stem ".png"] img 'png
    ]

    ; PDF page count (same cwd, so %010-hello.red.png resolves)
    out: to-file rejoin [root "tests/parity-" (replace form sample ".red" ".pdf")]
    report-pdf/generate pg out
    content: read/binary out
    pdf-n: 0
    pos: content
    while [p: find pos #{2F54797065202F50616765}][      ; "/Type /Page"
        ; /Type /Pages is the page tree, not a page object
        unless p/12 = 115 [pdf-n: pdf-n + 1]              ; 115 = #"s"
        pos: skip p 1
    ]
    if all [not keep? exists? out][delete out]

    result: rejoin [
        form sample "  view-pages=" form view-n
        "  pdf-pages=" form pdf-n
        either view-n = pdf-n ["  MATCH"]["  DIFF"]
        render-note
    ]
    write res-file result
    0
]

either error? err [
    write err-file mold err
    print mold err
    quit/return 1
][
    if exists? err-file [delete err-file]
    print result
    quit/return 0
]
