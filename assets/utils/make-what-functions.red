Red [
    Title: "Generate what-functions.txt"
    Demo:  "Snapshot Red's function list for samples/110-long-text.red"
    Note:  {Run with the same Red/View build used to view the samples:
            red-view assets/utils/make-what-functions.red
            It writes assets/what-functions.txt next to this script.}
]

; The report sample loads the snapshot instead of calling `what` at render time,
; so the report is reproducible and independent of the running session (the
; sampler's helper functions would otherwise appear in the listing).
;
; The snapshot is ONE Red block in this shape:
;   [ ["action!"   [ ["name" "description"] ... ] ]
;     ["function!" [ ... ] ] ... ]
; `load` reads it back directly; the sample no longer contains the parsing code.

system/console/size: 600x40          ; wide enough for the descriptions
; Capture `what` *before* defining the helpers below: `what` lists function
; definitions, and they must not end up in their own snapshot.
raw: what/buffer

group-rows: function [rows [block!]] [
    result: copy []
    last-type: none
    group: none
    foreach row rows [
        either row/1 = last-type [
            append group reduce [next row]
        ][
            last-type: row/1
            group: copy []
            append/only result reduce [last-type group]
            append group reduce [next row]
        ]
    ]
    result
]

what-functions: does [
    lines: split raw #"^/"
    result: collect [
        foreach line lines [
            keep/only parse line [
                collect [some %" "
                    keep copy w to #" " some #" "   ; word + skip all spaces
                    keep copy t to #" " some #" "   ; type + skip all spaces
                    keep copy d to end              ; rest
                ]
            ]
        ]
    ]
    result2: copy []
    foreach item result [
        unless none? item/1 [
            append/only result2 reduce [item/2 item/1 item/3]
        ]
    ]
    group-rows sort result2
]

; what-dir is this script's directory, so the snapshot lands next to it
write %../what-functions.txt mold what-functions
