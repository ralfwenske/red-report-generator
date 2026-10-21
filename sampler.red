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
    page: compose/deep [580x160 margin/10 [BODY [
        ["Error:" [f2 red]]
        [ (rejoin ["  " (msg) "  "]) [ black gray2]]
    ]]]
    show-popup "ERROR" page 400x80
]

; Handler bodies run inside the VID action blocks. Keep every variable local to a
; named function: a bare `x: ...` in an action block sets a *global*, and a name
; that collides with one used by a layout (e.g. the viewer's `p:` / `f`) can
; corrupt the VID/View state so that later windows fail to build ("VID - invalid
; syntax ...") until the process is reloaded. `function` auto-localises the
; set-words, so `f`, `p`/`modfile`, `saved`, `result`, `num` … never leak.

render-selected: func [/local saved f modfile result] [
    ; run with cwd = the sample's directory so its %../libs and %../assets
    ; relative paths resolve, then restore (like `do f`)
    saved: what-dir
    if modified [
        f: to-string files/(list/selected)
        ; if we are already editing a *-mod.red variant, save in place
        modfile: either find f "-mod.red" [f][replace copy f ".red" "-mod.red"]
        write to-file modfile editor/text
        modified: false
        get-samples
        list/data: names
        list/selected: index? find files to-file modfile
    ]
    show-status: ""
    result: try [context load editor/text]
    change-dir saved
    either error? result [
        error-popup form result
    ][
        if all [string? show-status show-status <> ""][error-popup show-status]
    ]
]

select-item: func [/local f] [
    f: to-file files/(list/selected)
    editor/text: read f
    modified: false
    replace-btn/enabled?: find f "-mod.red"
    editor/enabled?: find f "-mod.red"
    modify-btn/enabled?: if (
        (not find f "-mod.red") and
        (not (exists? to-file replace f ".red" "-mod.red"))
    ) [true] [false]
]

replace-original: func [/local f-mod f] [
    f-mod: to-file files/(list/selected)
    f: to-file replace files/(list/selected) "-mod" ""
    write to-file f editor/text
    delete f-mod
    modified: false
    get-samples
    list/data: names
    list/selected: find files f
    editor/enabled?: false
    replace-btn/enabled?: false
]

create-mod: func [/local selctd] [
    write to-file replace files/(list/selected) ".red" "-mod.red" editor/text
    selctd: list/selected
    get-samples
    list/data: names
    list/selected: selctd
    editor/enabled?: true
    modify-btn/enabled?: false
    replace-btn/enabled?: true
]

new-sample: func [/local num] [
    num: 10 + to-integer first split last list/data #"-"
    if num < 200 [num: 200]
    editor/text: read %samples/.000-template-mod.red
    replace editor/text "000 — Template" rejoin [to-string num " — My Sample"]
    write to-file rejoin [%samples/ num "-mysample.red"] editor/text
    write to-file rejoin [%samples/ num "-mysample-mod.red"] editor/text
    get-samples
    list/data: names
    list/selected: index? find list/data rejoin [num "-mysample-mod.red"]
    modified: false
    editor/enabled?: true
    replace-btn/enabled?: false
]

view/flags [
    title "Report Generator Sampler"    
    size 950x740
    backdrop yellow2

    below
    h2 "Report Generator Sampler"
    h4 "Select a sample to show its source. Double-click code area to render it."
    h4 "A modified sample will be saved under <filename>-mod.red"
    h4 "so the original file is preserved"
    panel 300x50 yellow3 [
        button "Render Report" [render-selected]
        replace-btn: button "Replace Original" disabled [replace-original]
        modify-btn: button "Create -mod file" disabled [create-mod]
        button "New Sample" [new-sample]
        button "Save Image" [ 
            save/as %sampler.png to-image face/parent/parent 'png 
        ]
        button "Quit"  [quit] 
            react [face/offset: face/parent/size - 70x40]
    ] react [face/size/x: face/parent/size/x - 20]
    across
    list: text-list 240x560 data names
        on-select [select-item]
        react [face/size/y: face/parent/size/y - 230]

    editor: area 660x560 disabled wrap gray3 font-name "Fixedsys" 
        on-key [modified: true]
        react [editor/size: (editor/parent/size - 270x230) 
            face/color: either face/enabled? [white][gray3]
        ]
    return


    do [
        if not empty? names [
            list/selected: 2
            editor/text: read files/2
        ]
    ]
][resize]
