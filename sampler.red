Red [
    File:  %sampler.red
    Title: "Report Generator Sampler"
    Demo:  "Browse and render the report samples"
    Needs: 'View
    Note:  {Run with the GUI build:  red-view sampler.red
            Each sample opens its own viewer window; close it to return.}
]

; Red already starts us in the script's own directory, so %samples/ and the
; samples' %assets/... resolve regardless of the launch cwd. Fall back to the
; script path from system/options/script if we are ever started elsewhere.
unless exists? %samples/ [
    change-dir first split-path system/options/script
]

;--- discover the samples: only *.red, sorted by filename -------------------

entries: copy []
foreach f read %samples/ [
    if all [file? f (suffix? f) = %.red] [
        append/only entries reduce [form f to-file rejoin ["samples/" f]]
    ]
]
sort entries
names: copy []
files: copy []
foreach e entries [
    append names e/1
    append files e/2
]

;--- read a sample's header metadata (defensively) --------------------------

demo-for: func [f [file!] /local blk hdr v out][
    out: "(no description)"
    blk: try [load f]
    if error? blk [return out]
    if all [not empty? blk word? blk/1 blk/1 = 'Red block? blk/2][hdr: blk/2]
    if block? hdr [
        v: select hdr 'Demo
        if string? v [out: v]
        v: select hdr 'Level
        if integer? v [out: rejoin [out "   (Level " v ")"]]
    ]
    out
]

;--- actions (kept out of the VID actors: `word:` there means a face facet) --

select-sample: func [i [integer!]][
    either all [i i > 0][
        demo/text: demo-for files/:i
        code/text: read files/:i
    ][
        demo/text: "(select a sample)"
    ]
]

render-sample: func [i [integer!] /local f e msg nl][
    if all [i i > 0][
        f: files/:i
        demo/text: rejoin ["Opening " f " ..."]
        set/any 'e try [do f]   ; blocks until the sample's window is closed
        case [
            not value? 'e [
                demo/text: rejoin ["Ran " f " (no status returned)"]
            ]
            error? e [
                msg: form e
                nl: find msg #"^/"
                demo/text: rejoin ["Error in " f ": " either not none? nl [copy/part msg nl][msg]]
            ]
            all [string? e e <> ""][
                demo/text: rejoin ["Invalid " f ": " e]
            ]
            true [
                demo/text: rejoin ["Closed " f " - double-click another sample"]
            ]
        ]
    ]
]

;--- ui ---------------------------------------------------------------------

win: layout [
    title "Report Generator Sampler"    
    size 950x740
    backdrop silver
    below
    h2 "Report Generator Sampler"
    h4 "Click a sample for its goal; double-click to show its source and render it."
    demo: h5 bold 760 "(select a sample)"
    across
    list: text-list 240x560 data names
        on-select [select-sample list/selected]
        on-dbl-click [render-sample list/selected]
        react [face/size/y: face/parent/size/y - 180]
    code: area 660x560 wrap font-name "Fixedsys" disabled 
        react [
            ;probe code/parent 
            code/size: (code/parent/size - 280x180) 
            ;probe code/size
        ]
        return
    button "Quit"  [quit]
        react [face/offset/y: face/parent/size/y - 40]
    do [
        if not empty? names [
            list/selected: 1
            demo/text: demo-for files/1
            code/text: read files/1
        ]
    ]
]

view/flags win [resize]
