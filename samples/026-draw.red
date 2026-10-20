Red [
    Title: "026 - Inline draw"
    Demo:  "DRAW: foreground vector art placed in the BODY flow (frames, badges, shapes)"
    Level: 3
    Needs: 'View
]

; [DRAW H [ops]] paints an allowlisted subset of the Red draw dialect as native
; vector art in the BODY flow, so it appears in both the View window and the PDF.
; H is the vertical space it consumes; the next item's top is H below the cursor.
; Inside the block, x/y are the current cursor (draw space, top-down), w is the
; content width, h is H, and prev-x/prev-y/prev-w/prev-h are the previous item's
; box — so a frame can be drawn around the paragraph just emitted.
; Supported: pen, fill-pen, line-width, line-join, line-cap, anti-alias,
; box (2 or 3 args: p1 p2 [radius]), circle, ellipse, line, triangle, polygon.
; See the Advanced usage section of docs/report-syntax-spec.md.

if exists? %samples/ [ change-dir %samples/ ]
img: load %../assets/Red_Language_Tower_Logo.png

report: [ margin/30
    [HEADER [["026 - Inline draw" [f2]]]]
    [BODY [
        ["This paragraph is framed by the DRAW that follows it: prev-* is its box." [b]]
        [DRAW 10 [
            pen 90.120.200
            fill-pen off
            line-width 1
            box (as-pair (prev-x - 4) (prev-y - 1))
                (as-pair (prev-x + prev-w + 4) (prev-y + prev-h + 4)) 6
        ]]
        ["The text continues below the frame."]
        []
        ["A row of vector shapes is drawn at the cursor; the text follows underneath."]
        [DRAW 344 [
            pen blue8
            fill-pen blue3
            line-width 2
            box (as-pair x y) (as-pair (x + 70) (y + 40)) 8
            circle (as-pair (x + 100) (y + 20)) 16
            line (as-pair (x + 130) y) (as-pair (x + 180) (y + 40))
            triangle (as-pair (x + 195) (y + 40)) (as-pair (x + 235) (y + 40)) (as-pair (x + 215) y)
            line-width 5
            pen yellow8
            fill-pen yellow4
            polygon (as-pair (x + 250) (y + 40)) (as-pair (x + 270) y) (as-pair (x + 290) (y + 40))
            image img 100x200 400x500
        ]]
        [[f2 red] "Text continues underneath the shapes."]
        ["(first argument after DRAW indicates height of draw box)"]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report/fit-width report "026 - Inline draw"
if error-msg <> "" [print error-msg]
