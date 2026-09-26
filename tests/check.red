Red [
    Title:   "Report generator sample checker"
    Purpose: {Headless parse + validate (optional PDF) over samples/.
              Run: red tests/check.red          parse + validate
                   red tests/check.red --pdf     also render each sample to a temp PDF}
]

; report-view pulls in report-parser (and report-pdf); loading it also makes
; report-view/make-font available to samples that set a base font.
#include %../libs/report-view.red

; Red starts in the script's own directory (tests/); move up to the repo root
; so %samples/ and %assets/ resolve.
change-dir %../
check-root: what-dir

args: any [system/options/args []]
want-pdf?: not none? find args "--pdf"

;--- helpers ----------------------------------------------------------------

head-word: func [v [any-type!]][
    case [
        word? v [v]
        path? v [v/1]
        true    [none]
    ]
]

show-call?: func [e [any-type!]][
    all [any [word? e path? e] (head-word e) = 'show-report]
]

captured-report: none

; Stub used while checking a sample: it captures the report block instead of
; opening a window.
show-report: func [
    report [block!] title [string!]
    /popup popup-fn
    /fit-width
][captured-report: report]

;--- one sample -------------------------------------------------------------

check-sample: func [f [file!] /local path blk start idx prefix e msg pg out skip-next][
    path: to-file rejoin ["samples/" f]
    blk: load path

    ; evaluate the sample from its own directory, as it is run normally, so its
    ; relative reads (own source, %assets/... data) resolve. The caller restores
    ; the repo root before the next sample.
    change-dir first split-path clean-path path

    ; skip the optional "Red [...]" header
    start: 1
    if all [not empty? blk word? blk/1 blk/1 = 'Red block? blk/2][start: 3]

    ; the last top-level expression is the show-report call
    idx: none
    repeat i length? blk [if show-call? blk/:i [idx: i]]

    ; evaluate the data/build expressions: skip the header and #include lines
    prefix: copy []
    skip-next: false
    repeat i (either idx [idx - 1][length? blk]) [
        if i < start [continue]
        if skip-next [skip-next: false continue]
        e: blk/:i
        if issue? e [skip-next: true continue]      ; "#include" + its file
        append/only prefix e
    ]
    do prefix

    ; capture the report block the sample hands to show-report
    captured-report: none
    either idx [
        do copy at blk idx
    ][
        captured-report: get/any 'report
    ]
    if none? captured-report [return "no report block (call show-report report {...})"]

    msg: validate-report captured-report
    if all ["" = msg want-pdf?][
        pg: parse-report captured-report
        out: clean-path to-file rejoin [check-root "check-" (replace form f ".red" ".pdf")]
        report-pdf/generate pg out
        delete out
    ]
    msg
]

;--- run all ----------------------------------------------------------------

; NB: the renderers set some globals (report-styles uses `f`, `s`, ...), so keep
; this driver's own words clearly namespaced to avoid being clobbered.
samples: copy []
foreach sf read %samples/ [
    if all [file? sf (suffix? sf) = %.red] [append samples sf]
]
sort samples

check-passed: 0
check-failed: 0
foreach sf samples [
    change-dir check-root   ; a failed render must not leave us in samples/
    check-res: try [check-sample sf]
    either error? check-res [
        check-failed: check-failed + 1
        check-msg: form check-res
        check-nl: find check-msg #"^/"
        print rejoin [pad form sf 22 "FAIL  " either not none? check-nl [copy/part check-msg check-nl][check-msg]]
    ][
        either "" = check-res [
            check-passed: check-passed + 1
            print rejoin [pad form sf 22 "PASS"]
        ][
            check-failed: check-failed + 1
            print rejoin [pad form sf 22 "FAIL  " check-res]
        ]
    ]
]

print ""
print rejoin ["samples: " (check-passed + check-failed) "   passed: " check-passed "   failed: " check-failed]
quit/return (either check-failed > 0 [1][0])
