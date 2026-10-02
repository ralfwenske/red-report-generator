Red [
    Title: "027 - Frame"
    Demo:  "FRAME: measure a group of BODY lines, then draw a backdrop behind them"
    Level: 3
    Needs: 'View
]

; [FRAME R [draw-ops] [items]] lays out [items] to measure them, then draws the
; [draw-ops] backdrop behind them (R = padding). The ops are the same allowlisted
; draw subset as DRAW; inside them x/y/w/h is the padded frame box and cx/cy/cw/ch
; the measured content box (both in page/draw space, top-down). Rendered as native
; vector by both the View and the PDF.

report: [ 800x900 margin-30
    [HEADER [["027 - Frame" [h2]]]]
    [BODY [
        ["A FRAME wraps the lines below and measures them before drawing its backdrop." [m]]
        []
        [FRAME 8 [
            pen 90.120.200  fill-pen 238.242.255  line-width 1
            box (as-pair x y) (as-pair x + w y + h) 6
        ] [
            ["This paragraph is inside the frame. It is long enough that it wraps onto a second visual line, giving the frame some height." [b]]
            ["A second line inside the same frame." [m]]
        ]]
        []
        ["Normal flow continues below the frame." [m]]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report/fit-width report "027 - Frame"
if error-msg <> "" [alert error-msg]
