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
    across
    list: text-list 240x560 data names
        on-select [
            code/text: read files/(list/selected)
            modified: false
            save-btn/enabled?: false
        ]
        react [face/size/y: face/parent/size/y - 160]

    code: area 660x560 wrap font-name "Fixedsys" 
        on-dbl-click [
            ; run with cwd = the sample's directory so its %../libs and
            ; %../assets relative paths resolve, then restore (like `do f`)
            saved: what-dir
            change-dir first split-path files/(list/selected)
            result: try [do load code/text]
            change-dir saved
            either error? result [
                show-error form result
            ][
                either ("" = result) [
                    if modified [save-btn/enabled?: true]
                ][
                    show-error result 
                ]
            ]
        ]
        on-key [modified: true]
        react [code/size: (code/parent/size - 280x160) ]
    return

    save-btn: button "SAVE *-mod.red" disabled [
        f: files/(list/selected)
        unless find f "-mod.red" [
            replace f ".red" "-mod.red"
        ]
        write to-file f code/text
        modified: false
        get-samples  
        list/data: names
    ] react [face/offset/y: face/parent/size/y - 40]

    button "Quit"  [quit] react [face/offset: face/parent/size - 80x40]

    do [
        if not empty? names [
            list/selected: 2
            code/text: read files/2
        ]
    ]
][resize]
