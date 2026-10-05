Red [
    Title: "Code Viewer"
    Demo:  "View red code in a view"
    Level: 2
    Needs: 'View
]
if exists? %samples/ [      ;make sure we are in the script directory
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
    margin/10 920x700 ;a4 landscape
    [HEADER [
        ["Red Report" [h1 !m red] "Self Reflection" [h2]]
        ["Prepared <now>" [i] "" "<page> of <pages>" [b]]
    ]]
    [BODY [
        ["  Complete source which produced these pages (pure Red): " 
            [h2 !m gray white gray]
        ]
        []
        [COLUMN auto px/5 (bdy)]
        []
        ["  ABOUT  " [h2 link/123]]
        [ 
            "On next page the " 
            "  PDF Report  " [h2 100.100.100 yellow !m]
        ]
        [IMAGE %code-viewer.png]
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
        [[(rejoin [type " " id ": "]) (txt) [!m h2 b red black red] ] 
        ["Place any details about a value" [i]]
        ["or take any action" [i]]
        ]
    ]]
    show-popup rejoin [type " " id] rpt 280x70 
]

#include %../libs/report-view.red
report-view/make-font [m] 11
error-msg: show-report/popup report "code-viewer" :do-popup
if error-msg <> "" [alert error-msg]
