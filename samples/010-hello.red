Red [
    Title: "010 — Hello"
    Demo:  "BODY plus one line: the minimum viable report"
    Level: 1
    Needs: 'View
]

; A page is a block of items. [BODY [...]] is the required section; each
; block inside it is one line on the page. A line is value + style pairs,
; and [h2] makes this line a heading.
; HEADER and FOOTER are optional; they are repeated on every page.
; The first three values are placed on the left, centre and right of the line. 
; <page> and <pages> are replaced with the page number and total pages.
; the 'compose/deep' is needed to evaluate the date function inside the report block.

report: compose/deep [
    [HEADER [
        ["Red Report Generator" [h1] "" (now/date) ]
        ["" "***" (now) [datetime]]
        []
    ]]
    [BODY [
        ["Hello World" [h2 purple]]
        ["and line after line"]
        []
        ["and a blank line before this one"]
    ]]
    [FOOTER [
        ["Footer" [h3] "" "Page <page> of <pages>"]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report report "01 — Hello"
if error-msg <> "" [alert error-msg]
