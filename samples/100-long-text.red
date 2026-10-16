Red [
    Title: "100-long-text"
    Demo:  "A longer text report"
    Level: 1
    Needs: 'View
]

group-rows: function [rows [block!]] [
    result: copy []
    last-type: none
    group: none
    foreach row rows [
        either row/1 = last-type [
            append group reduce  [next row]
        ][
            last-type: row/1
            group: copy []
            append/only result reduce [last-type group]
            append group reduce [next row]
        ]
    ]
    result
]; group-rows

what-functions: does [
    system/console/size: 600x40     ;avoid trimming of long lines 
    lines: split what/buffer #"^/"  ;split into lines
    result: collect [
        foreach line lines [
            keep/only parse line [
                collect [some %" "
                    keep copy w to #" " some #" "   ; word + skip all spaces
                    keep copy t to #" " some #" "   ; type + skip all spaces
                    keep copy d to end              ; rest
                ]
            ]
        ]
    ]
    result2: copy []
    foreach item result [
        unless none? item/1 [ 
            append/only result2 reduce [item/2 item/1 item/3]
        ]
    ]
    group-rows sort result2
]; what-functions

compose [ ;what-functions returns this block structure:
[["action!" [ 
    ["absolute" "Returns the non-negative value."] 
    ]
 ["function!" [
    ["pair?" "Returns true if the value is this type."] 
    ]
]]]
]

whats: func [] [
    res: []
    foreach w what-functions [ ; action!  function! ...
        what-string: copy []
        append/only what-string         ;replace header to show (w/1)
            compose/deep [HEADER [
                ["Red Report Generator" [h1] "" (now/date) ]
                [(rejoin ["Type: " (uppercase w/1)]) [h3 red] "" (now) [datetime]]
                []
            ]]
        append/only what-string [PAGEBREAK] ;force new page for new (w/1)
        foreach wf w/2 [
            append/only what-string compose/deep [[m/10 ] (wf/1) [px/170] (wf/2) [s/7 ]]
            ;serif 10px for row, bold 170px wide for function name,  then text
        ]
        append res what-string
    ]
    res
]

report: compose/deep [ margin/10
    [HEADER [
        ["Red Report Generator" [h1] "" (now/date) ]
        ["" "***" (now) [datetime]]
        []
    ][
        ["Header Test" [h2] "" "This is a header for page 2 and after"] ; on page 2,3...
    ]]
    [BODY [    
        [[h3] "demonstrating HEADER FOOTER dynamics"]
        (whats)
    ]]
    [FOOTER [
        ["What function demo" "" "Page <page> of <pages>"] ; on page 1
    ][
        ["" "" "<page> of <pages>" ]                        ; on page 2,3...
    ]]
]

#include %../libs/report-view.red
show-report/fit-width report "100-simple-text"

