Red [
    Title: "200 — My Sample"
    Demo:  "Use me to experiment with the report generator"
    Level: 1
    Needs: 'View
]

{
    Describe here what features you are exploring
    Playing with colors 
}

colors: ['gray 'red 'pink 'grape 'violet 'indigo 'blue 'cyan 'teal 'green 'lime 'yellow 'orange]
{from https://yeun.github.io/open-color/}

make-color-table: function [][
    tbl-block: copy []
    append/only tbl-block compose [0 1 2 3 4 5 6 7 8 9]
    foreach col colors [
        cols: to-string col
        row: copy []
        repeat i 10 [
            style: copy []
            append style 'black 
            color: to-word rejoin [col i - 1]
            append row rejoin [cols i - 1]
            either i < 7 [
                append/only row reduce ['black (color)]
            ][
                append/only row reduce ['white (color)]
            ]
        ] 
        append/only tbl-block row
    ]
    tbl-src: compose/deep [TABLE ss ^ [(tbl-block)]]
]

report: [a4 landscape margin/20              ; A5 paper size 20px margins 
    [HEADER [
        ["  My Report  " [f2 white red7] "Demo" [blue] (now) [datetime]]
        []
    ]]
    [BODY [
        ["Put here your experiments"]
        []
        [(make-color-table)]
        ["color shades are defined in %report-styles.red" [m/9 b i]]
    ]]
    [FOOTER [
        ["Page <page> of <pages>" [f3] (now) [time] (now) [date]]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report/fit-width report "00 — Template"
if error-msg <> "" [print error-msg]
