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
    name-text: center name-text 12
    append/only col-cols-m compose/deep [(name-text) [m black (to tuple! rgb-text)]]
    append/only col-cols-s compose/deep [(name-text) [s black (to tuple! rgb-text)]]
    append/only col-cols-ss compose/deep [(name-text) [ss black (to tuple! rgb-text)]]
]

report: compose/deep [ 800x900 margin-10
    [HEADER [
        ["" "Pick a color" [h2 red]]
    ]]
    [BODY [
        [[m] "Color Picker " " Select a color:" [blue]]
        [COLUMN auto [
        (col-cols-m)
        ]]
        []
        [COLUMN auto [
        (col-cols-s)
        ]]
        []
        [COLUMN auto [
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


#include %../libs/report-view.red
error-msg: show-report/fit-width report "color-picker"
if error-msg <> "" [alert error-msg]