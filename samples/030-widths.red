Red [
    Title: "030 — Widths"
    Demo:  "character boxes (#Nch / N) vs literal pixels (#Npx) line up columns"
    Level: 3
    Needs: 'View
]

; A width on a line segment is a box: the next segment starts at its right
; edge. An integer (or #Nch) is that many average characters of the value's
; style, so like-styled lines line up; #Npx is literal pixels and is what you
; need when the lines mix styles. A numeric value with a box is right-aligned
; by default, so decimal points line up; a float w.d also sets d decimals.

report: [
    [BODY [
        ["Character box — 20 average characters of the value's style:" [f3]]
        ["Item one" [ch/20] "starts at the same x"]
        ["Item two" [ch/20] "on every line"]
        ["Item 3"   [ch/20] "because the box is style-relative"]
        ["12345678901234567890"   [ch/20] "because the box is style-relative"]
        []
        ["Pixel box — mixed styles need px/N:" [f3]]
        ["Item one" [px/160] "starts at 160 px"]
        ["Item two" [px/160 s b] "whatever the style"]
        []
        ["Numbers — the float's integer part is the box:" [f3]]
        ["Value:" [ch/20 >] 1234.5678 [i 10.2] "  box 15, 2 decimals, right-aligned"]
        ["Value:" [> ch/20] 42        [i 10.2] "  same box; decimal points line up"]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report/fit-width report "03 — Widths"
if error-msg <> "" [alert error-msg]
