Red [
    File: %010-hello.red
    Demo: "Report showing it's own source (dsl)"
    Level: 1
    Needs: 'View
] 
  
if exists? %samples/ [ change-dir %samples/ ]

attach-style: function [target [block!] pattern [string!] style [block!]][
    res: copy []
    foreach item target [
        either all [string? item find item pattern] [
            splt: split item pattern          
            append res reduce [(splt/1) (pattern) (style) (splt/2)]
        ]
        [append res compose reduce [(item)]]
    ]
    res
] ;attach-style

script: %010-hello.red
script-string: reduce [mold load script]
foreach pattern ["HEAD-ER" "BO-DY" "FOO-TER" ][
    p: replace pattern "-" ""
    script-string: attach-style script-string p [red b]
]

report: compose/deep [ margin/5
    [HEADER [
        ["Red Report Generator" [f1] "" (now/date) ]
        [(script) "***" (now) [datetime]]
        []  
    ]]
    [BODY [
        ["  The source code which produced this report:  " [f3 black yellow]]
        []
        [[m/9] (script-string) ]
        [PAGEBREAK]
        [IMAGE (reduce [rejoin [(script) ".png"]]) [
            "  A screenshot of this demo  " [f3  blue white blue]
        ]]
    ]]
    [FOOTER [
        ["" "Page <page> of <pages>"  ""]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report report to-string script
if error-msg <> "" [alert error-msg]