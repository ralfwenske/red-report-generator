Red [
    Title: "110 - Table of contents"
    Demo:  "h1/h2/h3 mark TOC entries; [TOC [patterns]] expands after pagination"
    Level: 2
    Needs: 'View
]

; h1/h2/h3 render exactly like the style-only f1/f2/f3, but they also register a
; heading for the table of contents. A [TOC [pattern lines]] item expands, once
; every page is known, into the collected headings in document (page) order. The
; pattern line naming a level supplies its format and indentation, so a level is
; listed exactly when a pattern line for it exists:
;   <h1>/<h2>/<h3>  the heading text            <t-page>  the page it is on
; `link/toc` in a pattern style block makes each entry clickable (View only):
; clicking jumps to the heading's page. Add `!u` to suppress the link underline.
; Pattern lines are ordinary value/style lines, so indentation (leading spaces)
; and px/N widths (to push the page number into a column) work as usual.

h1-style: [[h1 red]]

report: [
    margin/40
    [HEADER [
        ["TOC demo" [i] "" "Page <page> of <pages>"]
    ]]
    [BODY [
        ["Table of Contents" [f1]]
        []
        [TOC [
            ["<h1>"       [f2 px/300 link/toc]     "<t-page>" [f3]]
            ["    <h2>"   [f3 px/300 link/toc]     "<t-page>" [f3]]
            ["            <h3>" [f4 px/300 link/toc] "<t-page>" [f3]]
        ]]

        [FOOTER [
            ["110 - toc" [i] "Introduction" "Page <page> of <pages>"]
        ]]
        [PAGEBREAK]
        ["Introduction" (h1-style)]
        ["Some text under the introduction."]
        ["Background" [h2]]
        ["More text under the background heading."]

        [PAGEBREAK]
        ["Second Background" [h2]]
        ["More text under the second background heading."]

        [FOOTER [
            ["110 - toc" [i] "Methods" "Page <page> of <pages>"]
        ]]
        [PAGEBREAK]
        ["Methods" [h1]]
        ["Details of the methods used."]
        ["Data" [h2]]
        ["A note on the data."]
        ["Appendix" [h3]]
        ["A deeper heading, indented further in the contents."]
    ]]
    [FOOTER [
        ["110 - toc" [i] "" "Page <page> of <pages>"]
    ]]
]

#include %../libs/report-view.red
error-msg: show-report/fit-width report "110 - Table of contents"
if error-msg <> "" [print error-msg]
