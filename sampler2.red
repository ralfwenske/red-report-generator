Red [
    File:  %sampler2.red
    Title: "Report Generator Sampler"
    Demo:  "Browse and render the report samples"
    Needs: 'View
    Note:  {Each sample opens its own viewer window; close it to return.}
]

#include %libs/report-view.red

unless exists? %samples/ [      ;make sure we are in the script directory
    change-dir first split-path system/options/script
]

; Wrap show-report so a sample's validation/problem message (returned as a string)
; is not lost when the sample runs in its own context.
real-show-report: :show-report
show-status: ""
show-report: func [report [block!] title [string!] /popup popup-fn /fit-width][
    show-status: case [
        all [popup fit-width] [real-show-report/popup/fit-width report title :popup-fn]
        popup                 [real-show-report/popup report title :popup-fn]
        fit-width             [real-show-report/fit-width report title]
        true                  [real-show-report report title]
    ]
]
; samples call `alert error-msg`; the sampler shows that message itself
alert: func [msg [any-type!]][]

names: [] 
files: []
modified: false
;--- discover the samples: only *.red, sorted by filename -------------------
get-samples: func [/local f] [
    names: copy []
    files: copy []
    foreach f sort read %samples/ [
        if all [file? f (suffix? f) = %.red] [
            append names form f
            append files to-file rejoin ["samples/" f]
        ]
    ]
    modified: false
] ; get-samples
get-samples

show-error: function [msg [string!]] [
    page: compose/deep [ margin-10 [BODY [
        ["Error:" [h2 red]]
        [ (rejoin ["  " (msg) "  "]) [h3 white gray]]
    ]]]
    show-popup "ERROR" page 400x80
]

view/flags [
    title "Report Generator Sampler"    
    size 950x740
    backdrop silver

    below
    h2 "Report Generator Sampler"
    h4 "Select a sample to show its source. Double-click code area to render it."
    h4 "A modified sample will be saved under <filename>-mod.red"
    h4 "so the original file is preserved"
    across
    list: text-list 240x560 data names
        on-select [
            f: to-file files/(list/selected)
            src/text: read f
            modified: false
        ]
        react [face/size/y: face/parent/size/y - 230]

    src: area 660x560 wrap font-name "Fixedsys" 
        on-dbl-click [
            ; run with cwd = the sample's directory so its %../libs and
            ; %../assets relative paths resolve, then restore (like `do f`)
            saved: what-dir
            if modified [ 
                f: to-string files/(list/selected)
                ; if we are already editing a *-mod.red variant, save in place
                p: either find f "-mod.red" [f][replace copy f ".red" "-mod.red"]
                write to-file p src/text
                modified: false
                get-samples
                list/data: names
                list/selected: find files p
            ]
            show-status: ""
            result: try [context load src/text]
            change-dir saved
            either error? result [
                show-error form result
            ][
                if all [string? show-status show-status <> ""][show-error show-status]
            ]
        ]
        on-key [modified: true]
        react [src/size: (src/parent/size - 270x230) ]
    return


    button "Quit"  [quit] react [face/offset: face/parent/size - 70x40]

    do [
        if not empty? names [
            list/selected: 2
            src/text: read files/2
        ]
    ]
][resize]
