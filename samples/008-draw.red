Red [
    Title: "008 - Draw"
    Demo:  "Draw a background report"
    Level: 1
    Needs: 'View 
]
if exists? %samples/ [      ;make sure we are in the script directory
    change-dir %samples/
]
a-text: {Red's ambitious goal is to build the world's first full-stack language, a language you can use from system programming tasks, up to high-level scripting through DSL. You've probably heard of the term "Full-Stack Developer". But what is a full-stack Language, exactly?

Other languages talk about having "one tool to rule them all". Red has that mindset too, pushed to the limit - it's a single executable that takes in your source files on any platform, and produces a packaged binary for any platform, from any other. The tool doesn't depend on anything besides what came with your OS...shipping as a single executable that about a megabyte.

}
a-text2: compose [{But that technical feat alone isn't enough to define Red's notion of a "Full-Stack Language". It's about the ability to bend and redefine the system to meet any need, while still working with literate code, and getting top-flight performance.  So what's being put in your hands is more like a "language construction set" than simply "a language". Whether you're writing a device driver, a platform-native GUI application, or a shared library... } [black transparent] {Red lets you use a common syntax to code at the right level of abstraction for the task.} [black yellow] ] 

;do load %../assets/color-tuples.red
logo: load %../assets/Red_Language_Tower_Logo_Light.png
footer: compose/deep [[FOOTER [["Page <page> of <pages>" [f3] (now) [time] (now) [date]]]]]

font-play: function [fg-color [word!] bg-color [word!]][
    color-row: copy [[s/9 b i] ]
    repeat i 10 [
        rs: to-word rejoin [fg-color (i)]
        r: to-word rejoin [fg-color (i - 1)]
        g: to-word rejoin [bg-color (10 - i)]
        code: compose/deep [(rejoin [" " (to-string rs) " "]) [(r) (g)]]
        append color-row code
    ]
    color-row
]

report: [a4 margin/20 left/40      ; A4 paper size 20px margins 40px left
    [DRAW-BG [
        pen off
        fill-pen red3                          
        box 0x0 (as-pair 20 page-height)
        box 0x0 (as-pair page-width 60)
    ]]
    [HEADER [
        ["    Red" [f1 white ] "  Demo  " [blue white red] (now) [date white]]
        []
    ][
        ["Red" [f1 white ] "  Demo  " [blue white red] (now) [date white]]
        []
    ]]
    (footer)
    [BODY [
        [DRAW 0 [image logo 15x14 55x54]]
        ["Minimal Report Sample" [f1] ]                 ; f1 -> base size * 2
        [[f2] "About the " "Red " [red f1] "Language" ] ; f2 -> base size * 1.5 bold
        []
        [[m/18] (a-text) ]                            ; mono 9 px 9
        [PAGEBREAK 20]

        [[m/18 b] (a-text2)  ]                        ; mono 9 px bold 9
        ["(copied from red-lang.org)" [ss/8]]           ; sans-serif 8px
        []
        [[f3] "Visit " "  red-lang.org  " [red white red]  " for more info"]  
                                                        ; f3 -> base size * 1.25 
        []        
        [FRAME 8 [
            [(font-play 'red 'gray)]
            [(font-play 'gray 'red)]
            []
            [(font-play 'teal 'blue)]
            [(font-play 'blue 'teal)]
        ] [
            pen 90.120.200  fill-pen 238.242.255  line-width 2
            box (as-pair x y) (as-pair x + w y + h) 6

            image logo (as-pair w + 80  y) (as-pair w + 180 y + 100) 
        ]]
        []
        ["(a play with colors and drawing around the frame)"]
    ]]
]

#include %../libs/report-view.red
log: show-report/fit-width report "008 Header %page-size%"
if log <> "" [print log]