Red [
    Title: "090 — Links"
    Demo:  "link-N and hint-N, with a do-popup callback (View only)"
    Level: 3
    Needs: 'View
]

; link-N is a clickable hotspot and hint-N a hover hint; both auto-underline
; (link solid, hint dotted). They call the popup handler passed to
; show-report/popup. The handler is a normal function; here it builds a tiny
; report and shows it with show-popup. The PDF drops links and hints, so this
; is a View lesson.

do-popup: func [type [word!] id [word! number!] txt [string!] /local body page][
    body: rejoin [
        "You " either type = 'link ["clicked"] ["hovered"] " "
        form type " " form id ": " txt
    ]
    page: compose/deep [[BODY [
        [(body) [h3]]
        ["This popup is itself a report, shown with show-popup."]
        []
        ["In the report dialect you simply insert 'link-N' in a style block"]
        [{   ["Click " "this link" [link-1] " for a popup."]}  [i]]
        ["or"]
        [{   ["Hover " "this hint" [hint-2] " for a popup."]}  [i]]
    ]]]
    show-popup rejoin [form type " " form id] page 460x160
]

report: [
    [BODY [
        ["Links and hints" [h2]]
        ["Click " "this link" [link-1] " for a popup."]
        ["Hover " "this hint" [hint-2] " for a moment."]
        ["A link can carry any id: " "another" [link-42 blue] "."]
    ]]
]

#include %../libs/report-view.red

error-msg: show-report/popup/fit-width report "09 — Links" :do-popup
if error-msg <> "" [alert error-msg]
