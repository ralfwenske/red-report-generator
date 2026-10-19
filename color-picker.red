Red [
    File: %color-picker.red
]

if exists? %samples/ [      ;make sure we are in the script directory
    change-dir %samples/
]

center: func [t [string!] n [integer!] /local s gap left][
    s: copy t
    if (length? s) > n [return copy/part s n]

    gap: n - length? s
    left: to integer! round/down (gap / 2)

    pad/left s ((length? s) + left)
    pad s n
]

pick-text-color: function [ "Returns black or white depending on background contrast"
    color [tuple!]
][
    if glass = color [return black]
    r: color/1    g: color/2   b: color/3
    ; convert 0-255 channel to linear light
    lin: func [c [integer!] /local f [float!]][
        f: to-float c / 255.0
        either f <= 0.04045 [
            f / 12.92
        ][
            power ((f + 0.055) / 1.055) 2.4
        ]
    ]
    ; WCAG relative luminance
    lum: (0.2126 * lin r) + (0.7152 * lin g) + (0.0722 * lin b)
    either lum > 0.179 [black] [white]
]

col-cols-m: []
col-cols-s: []
col-cols-ss: []
ws: charset " ^-^/"
system/console/size: 600x40     ;avoid trimming of long lines
foreach c split help-string tuple! #"^/" [
    parse c [
        any ws
        copy name-text to ws
        some ws
        copy rgb-text to end
    ]    
    name-text: center name-text 18
    append/only col-cols-m compose/deep [(name-text) [m b link-color (pick-text-color (to tuple! rgb-text)) (to tuple! rgb-text)]]
    append/only col-cols-s compose/deep [(name-text) [s b (pick-text-color (to tuple! rgb-text)) (to tuple! rgb-text)]]
    append/only col-cols-ss compose/deep [(name-text) [ss b (pick-text-color (to tuple! rgb-text)) (to tuple! rgb-text)]]
]

report: compose/deep [ 800x900 margin/10
    [HEADER [
        ["" "Select and paste a color" [h2 red]]
    ]]
    [BODY [
        [[m] "Color Picker " " Select a color:" [blue]]
        [COLUMN auto [
        (col-cols-m)
        ]]
        []
        [COLUMN ch/15 [
        (col-cols-s)
        ]]
        []
        [COLUMN ch/20 [
        (col-cols-ss)
        ]]
        []
        [[h1 black green] "  H1 text with g and p  "]
        [[h1 black yellow] "  H1  g and p  "]
        []
        [[h2 black green] "  H2 text with g and p  "]
        [[h2 black yellow] "  H2  g and p  "]
        []
        [[h3 black green] "  H3 text with g and p  "]
        [[h3 black yellow] "  H3  g and p  "]
    ]]

]

do-popup: func [type [word!] id [word! number!] txt [string!] /local body page][
    txt-color: pick-text-color (get to-word trim txt)
    bg-color: get to-word trim txt
    write-clipboard to string! bg-color
    body: rejoin ["   You clicked " form id ": " txt "   "]
    page: compose/deep [ margin/5
        [BODY [
            [(body) [h3 txt-color bg-color]]
            [(rejoin [(to string! bg-color) "  copied to clipboard"]) [h2]]
        ]]
    ]
    show-popup rejoin [form type " " form id] page 360x100
]


#include %../libs/report-view.red
error-msg: show-report/fit-width/popup report "color-picker" :do-popup
if error-msg <> "" [alert error-msg]