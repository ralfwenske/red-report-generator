Red [
    Title: "015 — Paper"
    Demo:  "paper size, orientation and margins come from the page clause"
    Level: 2
    Needs: 'View
]

; The leading words/pair of the page set the paper: a4/a5/a3/letter/legal or a
; WxH pair (in points), landscape/portrait, and margins (margin-N, or top-N /
; bottom-N / left-N / right-N, in points). Both renderers use them. This page
; is landscape A5 with a 20 pt margin, so it is wider than it is tall.

report: [
    landscape a5 margin/20
    [HEADER [
        ["ACME Corp" [h1 red] "Quarterly Report" [h2]]
        ["Prepared <now>" [i] "" "Page <page> of <pages>" [b]]
    ]]
    [BODY [
        ["Landscape A5, 20 pt margins" [h2]]
        ["The paper clause comes first, before the items."]
        ["Try portrait, letter, or an explicit 600x800 pair."]
    ]]
    [FOOTER [
        ["Confidential" [b] "" "Page <page> of <pages>" [b]]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report report "15 — Paper"
if error-msg <> "" [alert error-msg]
