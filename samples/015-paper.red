Red [
    Title: "015 — Paper"
    Demo:  "paper size, orientation and margins come from the page clause"
    Level: 2
    Needs: 'View
]

text: {
abcdefghijkl mnopqrstuvwxyz abcdefghijkl mnopqrstuvwxyz abcdefghijkl mnopqrstuvwxyz abcdefghijkl mnopqrstuvwxyz 
ABCDEFGHIJKL MNOPQRSTUVWXYZ ABCDEFGHIJKL MNOPQRSTUVWXYZ ABCDEFGHIJKL MNOPQRSTUVWXYZ ABCDEFGHIJKL MNOPQRSTUVWXYZ 
1234567890 1234567890 1234567890 1234567890 1234567890 1234567890 1234567890 

}

report: compose/deep [
    margin/20
    [HEADER [
        ["ACME Corp" [f1 red] "Quarterly Report" [f2]]
        ["Prepared <now>" [i] "" "Page <page> of <pages>" [b]]
    ]]
    [BODY [
        ["Landscape A5, 20 pt margins" [f2]]
        ["The paper clause comes first, before the items."]
        ["Try portrait, letter, or an explicit 600x800 pair."]
        [(text) ]
        [(text) [ss]]
        [(text) [m]]
        [(text) [b]]
        [(text) [ss b]]
        [(text) [m b]]
    ]]
    [FOOTER [
        ["Confidential" [b] "" "Page <page> of <pages>" [b]]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report report "15 — Paper"
if error-msg <> "" [alert error-msg]
