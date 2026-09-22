Red [
    Title: "01 — Hello"
    Demo:  "BODY plus one line: the minimum viable report"
    Level: 1
    Needs: 'View
]

; A page is a block of items. [BODY [...]] is the required section; each
; block inside it is one line on the page. A line is value + style pairs,
; and [h2] makes this line a heading.

report: [
    [BODY [
        ["Hello World" [h2 purple]]
    ]]
]

#include %../libs/report-view.red

show-report/fit-width report "01 — Hello"
