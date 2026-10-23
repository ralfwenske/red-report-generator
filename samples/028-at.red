Red [
    Title: "028 - AT (absolute placement)"
    Demo:  "Place text at a page position; use prev-* to put text beside an element"
    Level: 2
    Needs: 'View
]

; AT is an overlay: it draws its text lines at an absolute page position
; (page coordinates, top-left = 0x0) and does NOT move the flow cursor.
; Coordinates are evaluated at render time, so prev-* (the box of the previous
; flow element) and page-*/cursor-* are available. AT items are text lines.
if exists? %samples/ [ change-dir %samples/ ]
report: [a4 margin/50
    [HEADER [
        ["AT demo" [f2]]
    ]]
    [BODY [
        ["An image, then text beside it using [AT ...] and prev-*:" [f3]]
        [IMAGE px/180 %../assets/Empress.jpg ["Empress"]]
        [AT (prev-x + prev-w + 20) prev-y [
            ["Beside the image" [b red]]
            ["The flow continues below the image;" [m]]
            ["AT is an overlay and does not move the cursor." [m]]
        ]]
        ["This line is still part of the normal flow."]
        []
        ["An absolute stamp at page position (20, 20):" [f3]]
        [AT 20 20 [
            ["  TOP-LEFT  " [f2 white red3 red]]
        ]]
        ["This line is still part of the normal flow."]
    ]]
    [FOOTER [
        ["Page <page> of <pages>" [f3]]
    ]]
]

#include %../libs/report-view.red
error-msg: show-report/fit-width report "028 - AT %page-size%"
if error-msg <> "" [print error-msg]
