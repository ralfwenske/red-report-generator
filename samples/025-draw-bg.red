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

report: [
    [DRAW-BG 3 [
        pen off
        fill-pen 238.242.255                            ; soft band across the top
        box 0x0 (as-pair page-width 46)
        fill-pen 226.232.246                            ; spine down the left edge
        box 0x0 (as-pair 6 page-height)
        pen 205.210.225  line-width 1  fill-pen off     ; margin-aware inner frame
        box (as-pair margin-left margin-top)
            (as-pair page-width - margin-left - margin-right
                     page-height - margin-top - margin-bottom)
    ]]
    [HEADER [
        ["Red Report Generator" [h1]]
    ]]
    [BODY [
        ["DRAW-BG demo" [h2]]
        ["The blue band, the left spine and the frame are one raw draw block."]
        ["It is painted once, on every page, behind the header and body text."]
        [pagebreak]
        ["Second page" [h2]]
        ["The same background appears again: DRAW-BG applies to all pages."]
    ]]
    [FOOTER [
        ["draw-bg" [h3] "" "Page <page> of <pages>"]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report report "025 — Draw background"
if error-msg <> "" [alert error-msg]
