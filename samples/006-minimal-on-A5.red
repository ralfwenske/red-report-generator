Red [
    Title: "006 - Minimal-on-A5"
    Demo:  "smallest report"
    Level: 1
    Needs: 'View
]

; simple example to test environment

a-text: {Red's ambitious goal is to build the world's first full-stack language, a language you can use from system programming tasks, up to high-level scripting through DSL. You've probably heard of the term "Full-Stack Developer". But what is a full-stack Language, exactly?

Other languages talk about having "one tool to rule them all". Red has that mindset too, pushed to the limit - it's a single executable that takes in your source files on any platform, and produces a packaged binary for any platform, from any other. The tool doesn't depend on anything besides what came with your OS...shipping as a single executable that about a megabyte.

}
a-text-2: compose [{But that technical feat alone isn't enough to define Red's notion of a "Full-Stack Language". It's about the ability to bend and redefine the system to meet any need, while still working with literate code, and getting top-flight performance.  So what's being put in your hands is more like a "language construction set" than simply "a language". Whether you're writing a device driver, a platform-native GUI application, or a shared library... } {Red lets you use a common syntax to code at the right level of abstraction for the task.} [black yellow] ] 

report: [a5 margin/20 left/50                           ; A5 paper size 20px margins except left 50px
    [BODY [
        ["Minimal Report Sample" [f1] ]                 ; f1 -> base size * 2
        [[f2] "About the " "red " [red f1] "language" ] ; f2 -> base size * 1.5 bold
        []
        [[m/11 i] (a-text) ]                            ; mono 11 px italic
        [PAGEBREAK 20]                                  ; page break if less 20 rows available
        [[m/11 i] (a-text-2) ]                          ; mono 11 px italic
        ["(copied from red-lang.org)" [ss/8]]           ; sans-serif 8px
        []
        [[f3] "Visit " "  red-lang.org  " [red white red]  " for more info"]  
                                                        ; f3 -> base size * 1.25  red font red box around
        []
    ]]
]

#include %../libs/report-view.red
show-report/fit-width report "006 — Minimal-on-A5 %page-size%"
