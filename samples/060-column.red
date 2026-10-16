Red [
    Title: "060 — Column"
    Demo:  "COLUMN auto vs ch/px, with rows built from a variable"
    Level: 3
    Needs: 'View
]

; A COLUMN flows its rows into as many columns as fit the page, balanced by
; height. The width is auto (widest row), a bare number in ch, or #Npx/#Nch;
; an optional second number is the gap. Here the same rows are laid out three
; ways. The rows come from a variable, spliced in with compose/deep.

items: [[
    ["one"] ["two"] ["three"] ["four"] ["five"] ["six"]
    ["seven"] ["eight"] ["nine"] ["ten"] ["eleven"] ["twelve"]
    ["thirteen"] ["fourteen"] ["fifteen"] ["sixteen"] ["seventeen"]
    ["eighteen"]
]]

report: compose/deep [
    [BODY [
        ["auto width" [f3]]
        [COLUMN auto (items)]
        []
        ["fixed 12ch, gap 2" [f3]]
        [COLUMN 12 2 (items)]
        []
        ["fixed #46px, gap #2px" [f3]]
        [COLUMN #46px #2px (items)]
        []
        ["fixed #90px" [f3]]
        [COLUMN #90px (items)]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report/fit-width report "06 — Column"
if error-msg <> "" [alert error-msg]
