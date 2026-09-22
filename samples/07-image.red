Red [
    Title: "07 — Image"
    Demo:  "IMAGE: caption, width in the style block, shadow/border and links"
    Level: 3
    Needs: 'View
]

; IMAGE takes a file and an optional caption line. There is no width argument:
; put #Npx/#Nch at the front of the caption's style block. shadow or border
; draws a box (with an optional colour and inset); link-N makes the whole image
; a hotspot (View only). Images are shared in assets/, so the path is relative
; to this sample file: %../assets/<name>.jpg.

report: [
    [BODY [

        ["Width, shadow, colour and a link:" [h3]]
        [IMAGE %../assets/Empress.jpg ["Empress" [#120px shadow 5 silver link-1]]]
        [IMAGE %../assets/Emperor.jpg ["Emperor" [#120px border  gold link-2]]]

        ["No caption, just a frame:" [h3]]
        [IMAGE %../assets/Magician.jpg ["" [border 2 silver]]]

        ["Intrinsic width; the caption defaults to the file name:" [h3]]
        [IMAGE %../assets/Empress.jpg]
    ]]
]

#include %../libs/report-view.red

show-report/fit-width report "07 — Image"
