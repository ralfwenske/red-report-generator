Red [
    Title: "070 — Image"
    Demo:  "IMAGE: width argument, caption, shadow/border and links"
    Level: 3
    Needs: 'View
]

; IMAGE args are matched by type, not position: optional width (px/N or ch/N), optional box modifier (shadow or border, with an
; optional /N inset — e.g. shadow/3 or border/2), optional box colour, optional
; alignment (< left, ^ centre, > right), then the source (file, string path or
; image!). Omit the width for intrinsic sizing
; contained to the page. The trailing caption line's style block is pure text
; styles (link/N makes the whole image a hotspot, View only). Images live in
; assets/, so paths are relative to this sample: %../assets/<name>.jpg.
;
; In the thumbnails COLUMN below, the width lives once in the COLUMN argument
; (bare number = ch, so px/60 keeps pixels); with no width in the image clause
; the contained images take the column width.

if exists? %samples/ [      ;make sure we are in the script directory
    change-dir %samples/
]
report: [
    [BODY [
        ["Intrinsic width; the caption defaults to the file name:" [f3]]
        [IMAGE %../assets/Empress.jpg]

        ["Width as the first argument (bare number = px):" [f3]]
        [IMAGE px/120 shadow/3 silver %../assets/Empress.jpg ["Empress" [link/1]]]
        [IMAGE px/200 border gold %../assets/Emperor.jpg ["Emperor" [link/2]]]

        ["No caption, just a frame:" [f3]]
        ["(automatic pagebreak as it is too tall for the page)" [f3]]
        [IMAGE border/2 silver %../assets/Magician.jpg [""]]

        ["A generated (in-memory) image — no file needed:" [f3]]
        [IMAGE px/80 border/1 silver (make image! reduce [200x100 0.128.255]) ["generated" [b white green]]]

        ["Alignment: < left (default), ^ centre, > right — the token sits in the args:" [f3]]
        [IMAGE < px/100 %../assets/Empress.jpg [""]]
        [IMAGE ^ px/100 %../assets/Empress.jpg [""]]
        [IMAGE > px/100 %../assets/Empress.jpg [""]]

        ["Thumbnails (the COLUMN width also sizes the images):" [f3]]
        [COLUMN px/60 gap-px/10 image [shadow/5 silver link/1 s/8][
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
