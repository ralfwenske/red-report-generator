Red [
    Title: "025 — Draw background"
    Demo:  "DRAW-BG: one raw draw block painted behind every page"
    Level: 3
    Needs: 'View
]

; DRAW-BG runs before HEADER/BODY/FOOTER on every page. Its block is the raw
; Red/View draw dialect; parenthesised expressions are evaluated once by the
; renderer with the page geometry in scope (page-width, page-height, ...).
; Because of that the report block below is NOT composed at load time.
; An optional integer after DRAW-BG sets the pixel density used when the
; background is rasterized for PDF output (default 3).
; NOTE: raw draw exists only in Red/View, so a PDF built with plain `red`
; (no GUI) omits the background.

if exists? %samples/ [ change-dir %samples/ ]
do load %../assets/color-tuples.red
img: load %../assets/Red_Language_Tower_Logo.png 10x200

report: [ top/80
    [DRAW-BG 100 [
        pen off
        fill-pen green3                          ; soft band across the top
        box 0x0 (as-pair page-width margin-top - 10)
        fill-pen green3                            ; spine down the left edge
        box (as-pair 0 margin-top - 10) (as-pair 6 (page-height))
        pen 205.210.225  line-width 3  fill-pen off     ; margin-aware inner frame
        box (as-pair margin-left margin-top)
            (as-pair page-width - margin-right
                     page-height - margin-bottom)
        pen 223.143.255
        anti-alias on ; this is the default
        ;text 10x5 "With"
        ;text 10x15 "anti-alias"
        ;circle 40x50 20
        ;ellipse 200x10 250x60
        image img (as-pair (page-width / 2) - 25 10) (as-pair (page-width / 2) + 25 60)
    ]]
    [HEADER [
        ["Red Report Generator" [f1]]
    ]]
    [BODY [
        ["DRAW-BG demo" [f2]]
        ["The blue band, the left spine and the frame are one raw draw block."]
        ["It is painted once, on every page, behind the header and body text."]
        [IMAGE ^ px/400 %../assets/Red_Language_Tower_Logo.png ]
        []
        ["This logo appears only on this page" [m px/495 ^]] 
        [PAGEBREAK]
        ["The same background appears again: DRAW-BG applies to all pages."]
    ]]
    [FOOTER [
        ["draw-bg" [f3] "" "Page <page> of <pages>"]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report/fit-width report "025 — Draw background %page-size%"
if error-msg <> "" [alert error-msg]
