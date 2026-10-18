Red [
    Title: "Code Viewer"
    Demo:  "View red code in a view"
    Level: 2
    Needs: 'View
] 

;make sure we are in the script directory
if exists? %samples/ [     
    change-dir %samples/
]

code: read/lines %code-viewer.red
bdy: [ []]

highlight: []
append highlight rejoin ["HEAD" "ER"]
append highlight rejoin ["BOD" "Y"]
append highlight rejoin ["FOOT" "ER"]

foreach line code [
    foreach hl highlight [
        if find line hl [
            splt: split line hl
            if (length? splt) > 1 [
                line: reduce [
                    splt/1   
                    (hl)  [b red ] 
                    splt/2
                ]
            ]
        ]
    ]
    append/only bdy/1 compose [(line)]
]

report: compose/deep [
    margin/10 ;920x900 ;a4 landscape
    [HEADER [
        ["Red Report" [f1 !m red] "Self Reflection" [f2]]
        ["Prepared <now>" [i] "" "<page> of <pages>" [b]]
        []
    ]]
    [BODY [
        ["  Complete source : " 
            [f2 !m gray white gray]
        ]
        []
        ;[COLUMN px/280 0 (bdy)]
        [COLUMN auto gap-ch/0 (bdy)]
        []
        ["  ABOUT  " [f2 link/123]]
        [ 
            "On next page the " 
            "  PDF Report  " [f2 100.100.100 yellow !m]
        ]
        [IMAGE px/800 %code-viewer.png]
    ]]
    [FOOTER [
        [(now/date) [i]]
        ["Confidential" [b] "" "Page <page> of <pages>" [b]]
    ]]
]    
do-popup: function [
    type [lit-word! word!] id [number!] txt [string!]
][
    rpt: compose/deep [margin/5 [BODY 
        [[
            (rejoin [type " " id ": "]) 
            (txt) [!m f2 b red black red] 
         ] 
         ["Place any details about a value" [i]]
         ["or take any action" [i]]
        ]
    ]]
    show-popup rejoin [type " " id] rpt 280x70 
]

#include %../libs/report-view.red
report-view/make-font [ss] 8
msg: show-report/popup 
    report "code-viewer" :do-popup
if msg <> "" [alert msg]