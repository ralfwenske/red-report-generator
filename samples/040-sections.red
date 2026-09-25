Red [
    Title: "040 — Sections"
    Demo:  "PAGEBREAK, with the <page> and <pages> tokens"
    Level: 2
    Needs: 'View
]

; A page has up to three sections: HEADER lines sit at the top of every page,
; FOOTER lines at the bottom, and BODY holds the content. Within a header or
; footer line the 1st, 2nd and 3rd segments are placed left, centre and right.
; <page> and <pages> are replaced by both renderers; <now> works inside a
; string too.

report: [
    [HEADER [
        ["ACME Corp" [h1 red] "Quarterly Report" [h2]]
        ["Prepared <now>" [i] "" "Page <page> of <pages>" [b]]
    ]]
    [BODY [
        ["This is page one." [h2]]
        ["The header and footer repeat on every page."]
        [PAGEBREAK]
        ["This is page two." [h2]]
        ["The page tokens count the pages for you."]
    ]]
    [FOOTER [
        ["Confidential" [b] "" "Page <page> of <pages>" [b]]
    ]]
]

#include %../libs/report-view.red

show-report/fit-width report "04 — Sections"
