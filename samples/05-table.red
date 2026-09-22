Red [
    Title: "05 — Table"
    Demo:  "TABLE BOX ALT: header row, column widths/formats, page splitting"
    Level: 2
    Needs: 'View
]

; The first row of a TABLE is its header: its style blocks define each column
; (width in ch, alignment, number format). BOX draws the borders, ALT shades
; every second data row. A table that runs out of room continues on the next
; page and repeats the header; [PAGEBREAK] forces that here.

report: [
    [BODY [
        ["Widget sales" [h2]]
        [TABLE BOX ALT [
            ["Product" [< 18] "Qty" [> 6] "Unit" [> 10 money] "Total" [> 12 money]]
            ["Widget A" 120 25.00 3000.00]
            ["Widget B" 45 42.00 1890.00]
            ["Widget C" 12 35.00 420.00]
            ["Widget D" 7 199.00 1393.00]
            [PAGEBREAK]
            ["Gadget X" 3 149.50 448.50]
            ["Gadget Y" 9 12.75 114.75]
            ["TOTALS" [b] "" "" 7266.25 [b money]]
        ]]
    ]]
]

#include %../libs/report-view.red

show-report/fit-width report "05 — Table"
