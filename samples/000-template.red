Red [
    Title: "000 — Template"
    Demo:  "copy me: the sample contract and the smallest report"
    Level: 1
    Needs: 'View
]

; One file = one lesson. To add a sample: copy this file, give it the next
; numeric prefix (04-, 05-, …) and keep it short enough to read in the pane.
;
; Header fields
;   Title  the lesson name shown in the list title
;   Demo   the one-line goal the sampler shows on click
;   Level  optional difficulty, shown next to the goal
;   Needs  'View for anything that renders (the sampler runs under red-view)
;
; The report itself is a block of items assigned to `report`; the sampler and
; tests/check.red pick it up from the show-report call at the bottom.
; show-report validates the description itself: it opens the window only when
; the report is valid and returns "" (after the window is closed), otherwise it
; returns the problem message without opening a window.
; Shared images live in assets/ and are referenced relative to this file as
; %../assets/<name>.jpg (a `do`ne script runs with its own directory as cwd).

report: [
    [BODY [
        ["Replace this line with a couple of ideas this sample teaches" [f3]]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report/fit-width report "00 — Template"
if error-msg <> "" [alert error-msg]
