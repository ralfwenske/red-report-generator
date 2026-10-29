Red [
    Title: "200 — My Sample"
    Demo:  "Use me to experiment with the report generator"
    Level: 1
    Needs: 'View
]

{
    Describe here what features you are exploring
}

report: [a5 margin/20              ; A5 paper size 20px margins 
    [HEADER [
        ["  My Report  " [f2 white red7] "Demo" [blue] (now) [datetime]]
        []
    ]]
    [BODY [
        ["Put here your experiments"]
    ]]
    [FOOTER [
        ["Page <page> of <pages>" [f3] (now) [time] (now) [date]]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report/fit-width report "00 — Template"
if error-msg <> "" [print error-msg]
