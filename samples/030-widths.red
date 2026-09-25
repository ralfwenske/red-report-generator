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
        ["Character box — 20 average characters of the value's style:" [h3]]
        ["Item one" [20] "starts at the same x"]
        ["Item two" [20] "on every line"]
        ["Item 3"   [20] "because the box is style-relative"]
        ["12345678901234567890"   [20] "because the box is style-relative"]
        []
        ["Pixel box — mixed styles need #Npx:" [h3]]
        ["Item one" [#160px] "starts at 160 px"]
        ["Item two" [#160px s b] "whatever the style"]
        []
        ["Numbers — the float's integer part is the box:" [h3]]
        ["Value:" [20 >] 1234.5678 [i 10.2] "  box 15, 2 decimals, right-aligned"]
        ["Value:" [> 20] 42        [i 10.2] "  same box; decimal points line up"]
    ]]
]

#include %../libs/report-view.red

show-report/fit-width report "03 — Widths"
