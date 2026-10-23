Red [
    Title: "Make Colors from open-color.code-snippets"
]

cl: load %colors.json
f: ""
bk: copy []
foreach k keys-of cl [
    c: cl/(k)
    prefix: split first c/prefix "-"
    color-name: rejoin [prefix/2 prefix/3]
    append f reduce [color-name ": " to tuple! load first c/body newline]
    append bk compose/deep [(to-set-word color-name)  (to tuple! load first c/body)]
]
save %../color-tuples.red f

