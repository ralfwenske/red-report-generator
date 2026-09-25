Red [
    Title: "020 — Styles"
    Demo:  "bold, italic, underline, mono and colours; alignment on one line"
    Level: 2
    Needs: 'View
]

; Every value carries its own style block. Decorations (b i u s m h1-h3)
; combine; the trailing 1-3 colours are font, background and frame.
; Number in style determines cell width: integer or #Nch is average characters of the value's style,
; #Npx is literal pixels. A float w.d sets the box width to w and the number of decimals to d. 
; The default alignment is right for numbers and left for everything else.
; < ^ > are left, centre and right alignment.

report: [
    [BODY [
        ["bold " [b] "italic " [i] "underline " [u] "sans " [s] "mono " [m]]
        []
        ["red " [red] " white on blue " [white blue] " - "  "  boxed  " [black yellow red]]
        ["|" "left" [< 10] "|" "centre" [^ 10] "|" "right" [> 10] "|"] 
        ["|" "left" [< 10] "|" "centre" [^ 10 s b] "|" "right" [> 10] "|"] 
        ["|" "left" [< 10] "|" "centre" [^ 10 s b] "|" 5467 [10] "|"] 
        []
        ["|" "left" [< 10] "|" "centre" [^ #70px] "|" "right" [> 10] "|"] 
        ["|" "left" [< 10] "|" "Centre" [^ #70px s b] "|" "right" [> 10] "|"] 
    ]]
]

#include %../libs/report-view.red

show-report/fit-width report "02 — Styles"
