Red [
    Title: "130 — Color Shades"
    Demo:  "Table showing integrated red color shades"
    Level: 1
    Needs: 'View
]  

colors: ['gray 'red 'pink 'grape 'violet 'indigo 'blue 
         'cyan 'teal 'green 'lime 'yellow 'orange]
; from https://yeun.github.io/open-color/

if exists? %samples/ [ change-dir %samples/ ]
shade-img: load %../assets/shades.png

make-color-table: function [][
    tbl-block: copy []
    append/only tbl-block compose [0 1 2 3 4 5 6 7 8 9]
    foreach col colors [
        row: copy []
        repeat i 10 [
            color: rejoin [col i - 1]
            append row color
            either i < 8 [
                append/only row reduce ['black (to-word color)]
            ][
                append/only row reduce ['b 'white (to-word color)]
            ]
        ] 
        append/only tbl-block row
    ]
    tbl-src: compose/deep [TABLE ss/10 ^ [(tbl-block)]]
]

report: [a4 landscape margin/20   
    [HEADER [
        [[f2] "  Red Color Shades  " [white red3 red] 
            "Report Generator Demo" [blue] 
            (now) [datetime]]
        []
    ]]
    [BODY [
        ["A table example on A4 landscape :"]
        [(make-color-table)]
        []
        ["shades copied from https://yeun.github.io/open-color/" [s/14 m b i]]
        []
        ["color shades are embedded in report generator" [s/14 m i]]
        ["page 3 contains code that allows shades to be used in red apps" [s/14 m i]]
        [FOOTER [
            ["Page <page> of <pages>" [f3] "code which produced this report" [f2] (now) [date]]
        ]]
        [PAGEBREAK]
        [IMAGE px/380 %../assets/130-color-shades-1.png [""]]
        [AT (prev-x + prev-w + 5) (prev-y - 20) [
            [IMAGE px/400 %../assets/130-color-shades-2.png [""]]
        ]]
        [[i] {NOTE: these two images are raster screenshots. At "Fit Width" the page is scaled below 100% and GTK resamples the bitmaps (Red's DRAW exposes no image filter; see Red issue #4729). They therefore look softer than the vector text. 
The PDF embeds the full-resolution image; view at 100% or more to judge the image sharpness itself.}
        ]
        [FOOTER [
            ["Page <page> of <pages>" [f3] "color for any red app" [f2] (now) [date]]
        ]]
        [PAGEBREAK]
        [FRAME 8 [
            [[ss/8] (mold load %../assets/utils/shades.red)]
        ][
            image shade-img (as-pair w - 500 h - 50) 
        ]]
    ]]
    [FOOTER [
        ["Page <page> of <pages>" [f3] 
         "   make red apps colorful   " [f2 blue8 blue1] 
         (now) [date]]
    ]]
]

#include %../libs/report-view.red
error-msg: show-report/fit-width report "130 — Color Shades %page-size%"
if error-msg <> "" [print error-msg]
