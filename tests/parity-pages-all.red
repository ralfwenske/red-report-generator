Red [
    Title:   "View/PDF page-count parity probe (all samples)"
    Purpose: {Render every samples/*.red with report-view and report-pdf and
              report both page counts. Run with red-view (needs size-text/draw).}
    Usage:   {red-view tests/parity-pages-all.red [sample...] [--render] [--zoom 100] [--keep]}
    Needs:   'View
    Tabs:    4
]

; Dev tool, not part of tests/check.red. Loops in-process over samples/*.red
; (skipping the scratch *-mod.red variants), or over the sample names given on
; the command line. For each sample it writes tests/parity-<sample>.txt (or
; tests/parity-<sample>-error.txt) and a tests/parity-all.txt summary, updated
; after every sample so partial progress survives an abort. Old Red 0.6.6
; builds may abort a long sweep after ~15 PDFs in one process; the summary then
; shows how far it got, and the remaining samples can be passed by name.

#include %../libs/report-view.red
change-dir %../          ; Red/View starts in the script's directory (tests/)
root: what-dir

args: any [system/options/args []]
render?: not none? find args "--render"
keep?: not none? find args "--keep"
zoom: 300
if zi: find args "--zoom" [zoom: to integer! pick args (index? zi) + 1]

; sample names are the non-option args ("--zoom" also consumes its value)
sample-args: copy []
i: 1
while [i <= length? args][
    a: pick args i
    case [
        a = "--zoom" [i: i + 2]
        find ["--render" "--keep"] a [i: i + 1]
        true [append sample-args copy a  i: i + 1]
    ]
]

show-report: func [
    report [block!] title [string!]
    /popup popup-fn
    /fit-width
][captured-report: report  ""]
alert: func [msg [any-type!]][]

run-one: func [
    "Render one sample; return [ok? message]."
    sample [string!]
    /local name stem path blk start idx i2 suffix-at prefix skip-next e err
        pg rv view-pages view-n img t0 t1 out content pdf-n p pos result
        res-file err-file render-note
][
    ; accept "010-hello.red" or "samples/010-hello.red"
    name: last split-path clean-path to-file sample
    stem: replace form name ".red" ""
    res-file: to-file rejoin [root "tests/parity-" stem ".txt"]
    err-file: to-file rejoin [root "tests/parity-" stem "-error.txt"]
    render-note: ""
    result: ""
    change-dir root

    err: try [
        path: to-file rejoin ["samples/" form name]
        blk: load path
        change-dir first split-path clean-path path

        start: 1
        if all [not empty? blk  word? blk/1  blk/1 = 'Red  block? blk/2][start: 3]

        idx: none
        repeat i2 length? blk [
            if all [word? blk/:i2  blk/:i2 = 'show-report][idx: i2]
        ]
        suffix-at: idx
        if all [idx  idx > 1  (type? blk/(idx - 1)) = set-word!][suffix-at: idx - 1]

        prefix: copy []
        skip-next: false
        repeat i2 (either suffix-at [suffix-at - 1][length? blk]) [
            if i2 < start [continue]
            if skip-next [skip-next: false  continue]
            e: blk/:i2
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
        out: to-file rejoin [root "tests/parity-" stem ".pdf"]
        report-pdf/generate pg out
        content: read/binary out
        pdf-n: 0
        pos: content
        while [p: find pos #{2F54797065202F50616765}][      ; "/Type /Page"
            unless p/12 = 115 [pdf-n: pdf-n + 1]              ; 115 = #"s"
            pos: skip p 1
        ]
        if all [not keep? exists? out][delete out]

        result: rejoin [
            form name "  view-pages=" form view-n
            "  pdf-pages=" form pdf-n
            either view-n = pdf-n ["  MATCH"]["  DIFF"]
            render-note
        ]
        change-dir root
        0
    ]

    either error? err [
        change-dir root
        if exists? res-file [delete res-file]
        write err-file mold err
        reduce [false rejoin [form name "  ERROR  " form err]]
    ][
        if exists? err-file [delete err-file]
        reduce [true result]
    ]
]

samples-to-run: copy []
either empty? sample-args [
    foreach f read %samples/ [
        s: form f
        if all [
            parse s [thru ".red" end]
            not find s "-mod.red"
        ][append samples-to-run s]
    ]
    sort samples-to-run
][
    foreach s sample-args [append samples-to-run s]
]
if empty? samples-to-run [
    print "no samples to run"
    quit/return 1
]

passed: 0  failed: 0
summary: copy ""
all-file: to-file rejoin [root "tests/parity-all.txt"]
foreach s samples-to-run [
    r: run-one s
    either r/1 [passed: passed + 1][failed: failed + 1]
    print r/2
    append summary r/2
    append summary newline
    write all-file summary
]
n: length? samples-to-run
line: rejoin ["samples: " form n "  passed: " form passed "  failed: " form failed]
print line
append summary line
append summary newline
write all-file summary
quit/return either failed = 0 [0][1]
