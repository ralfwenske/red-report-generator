Red [
    Title: "Make Colors from open-color.code-snippets"
]

cl: load %colors.json
f: ""
foreach k keys-of cl [
    c: cl/(k)
    prefix: split first c/prefix "-"
    color-name: rejoin [prefix/2 prefix/3]
    ;print [color-name ": " to tuple! load first c/body]
    append f reduce [color-name ": " to tuple! load first c/body newline]
]
save %../color-tuples.red f