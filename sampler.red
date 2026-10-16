Red [
    File:  %sampler.red
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

error-popup: function [msg [string!]] [
    page: compose/deep [580x160 margin-10 [BODY [
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
    panel 300x50 yellow [
        button "Render Report" [
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
                list/selected: index? find files to-file p
            ]
            show-status: ""
            result: try [context load src/text]
            change-dir saved
            either error? result [
                error-popup form result
            ][
                if all [string? show-status show-status <> ""][error-popup show-status]
            ]

        ]
        replace-btn: button "Replace Original" disabled [
            f-mod: to-file files/(list/selected)
            f: to-file replace files/(list/selected) "-mod" ""
            write to-file f src/text
            delete f-mod
            modified: false
            get-samples
            list/data: names
            list/selected: find files f
            src/enabled?: false
            face/enabled?: false
        ] 
        modify-btn: button "Create -mod file" disabled [
            write to-file replace files/(list/selected) ".red" "-mod.red" src/text
            selctd: list/selected
            get-samples
            list/data: names
            list/selected: selctd
            src/enabled?: true
            face/enabled?: false
            replace-btn/enabled?: true
        ]
        ;button "Save Image" [ save/as %sampler2.jpg to-image face/parent/parent 'jpeg ]
        button "Save Image" [ 
            save/as %sampler2.png to-image face/parent/parent 'png 
        ]
        button "Quit"  [quit] 
            react [face/offset: face/parent/size - 70x40]
    ] react [face/size/x: face/parent/size/x - 20]
    across
    list: text-list 240x560 data names
        on-select [
            f: to-file files/(list/selected)
            src/text: read f
            modified: false
            replace-btn/enabled?: find f "-mod.red"
            src/enabled?: find f "-mod.red"
            modify-btn/enabled?: if (
                (not find f "-mod.red") and
                (not (exists? to-file replace f ".red" "-mod.red"))
            ) [true] [false]
        ]
        react [face/size/y: face/parent/size/y - 230]

    src: area 660x560 disabled wrap silver font-name "Fixedsys" 
        on-key [modified: true]
        react [src/size: (src/parent/size - 270x230) 
            face/color: either face/enabled? [white][silver]
        ]
    return


    do [
        if not empty? names [
            list/selected: 2
            src/text: read files/2
        ]
    ]
][resize]
