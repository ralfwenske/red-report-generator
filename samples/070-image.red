Red [
    Title: "070 — Image"
    Demo:  "IMAGE: width argument, caption, shadow/border and links"
    Level: 3
    Needs: 'View
]

; IMAGE takes an optional width first, then the file, then an optional caption
; line. The width belongs to the image: a bare number is pixels (or #Npx/#Nch
; for an explicit unit). Omit it to use the intrinsic width, contained to the
; page. In the caption style block, shadow or border draws a box (with an
; optional colour and inset); link-N makes the whole image a hotspot (View
; only). Images are shared in assets/, so the path is relative to this sample
; file: %../assets/<name>.jpg.
;
; In the thumbnails COLUMN below, the width lives once in the COLUMN argument
; (bare number = ch, so #60px keeps pixels); with no width in the image clause
; the contained images take the column width.

if exists? %samples/ [      ;make sure we are in the script directory
    change-dir %samples/
]
report: [
    [BODY [
        ["Intrinsic width; the caption defaults to the file name:" [h3]]
        [IMAGE %../assets/Empress.jpg]

        ["Width as the first argument (bare number = px):" [h3]]
        [IMAGE 120 %../assets/Empress.jpg ["Empress" [shadow 3 silver link-1]]]
        [IMAGE 200 %../assets/Emperor.jpg ["Emperor" [border gold link-2]]]

        ["No caption, just a frame:" [h3]]
        ["(automatic pagebreak as it is too tall for the page)" [h3]]
        [IMAGE 120 %../assets/Magician.jpg ["" [border 2 silver]]]

        ["Thumbnails (the COLUMN width also sizes the images):" [h3]]
        [COLUMN #60px #10px image [shadow 5 silver link-1 s-8][
            [IMAGE %../assets/Empress.jpg]
            [IMAGE %../assets/Chariot.jpg]
            [IMAGE %../assets/Emperor.jpg]
            [IMAGE %../assets/Fool.jpg]
            [IMAGE %../assets/High_Priestess.jpg]
            [IMAGE %../assets/Judgement.jpg]
            [IMAGE %../assets/Justice.jpg]
            [IMAGE %../assets/Lovers.jpg]
            [IMAGE %../assets/Magician.jpg]
            [IMAGE %../assets/Moon.jpg]
        ]]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report/fit-width report "07 — Image"
if error-msg <> "" [alert error-msg]
