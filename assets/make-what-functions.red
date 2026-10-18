Red [
    Title: "Generate what-functions.txt"
    Demo:  "Snapshot Red's function list for samples/100-long-text.red"
    Note:  {Run with the same Red/View build used to view the samples:
            red-view assets/make-what-functions.red
            It writes assets/what-functions.txt next to this script.}
]

; The report sample reads this snapshot instead of calling `what` at render
; time, so the report is reproducible and independent of the running session
; (the sampler's helper functions would otherwise appear in the listing).
;
; Keep this script free of function definitions: `what` lists them, and they
; would end up in the snapshot.

system/console/size: 600x40                 ; wide enough for the descriptions
; what-dir is this script's directory, so the snapshot lands next to it
write %what-functions.txt what/buffer
