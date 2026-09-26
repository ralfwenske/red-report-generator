# Report Generator

A compact report generator written in **Red**. You describe a report as a single
declarative block; one parser turns it into a page object and **two independent
renderers** consume it:

- **View** — an interactive, multi-page window (links, hints, fit/full view).
- **PDF** — a self-contained PDF (pure Red, no Ghostscript).

## Run

```bash
red-view sampler.red
```

Click a sample for its one-line goal; double-click to show its source and render it.
The sampler needs the GUI build (`red-view`); close a sample's window to return.

## Add a sample

Copy `samples/000-template.red`, give it the next numeric prefix (`100-`, …), and keep
it to one idea. The numeric prefix sets the order; the header's `Demo:` line is the
lesson's one-line goal. Samples are the lessons **and** the regression fixtures.

Shared images live in `assets/` and are referenced from a sample relative to the
sample file as `%../assets/<name>.jpg`.

## View and PDF parity

The two renderers aim to look the same (same nominal sizes, metric-compatible faces,
and matched wrap points), tuned per family via `report-view/font-scale-*` and
`report-pdf/font-scale-*` (see the spec, §12). Serif and sans-serif glyphs vary in
width, so a perfect match is not possible for them. **For the closest match, use the
mono family (`m`)**: its fixed advance makes widths — and therefore line breaks —
line up between View and PDF.

## Check

```bash
red tests/check.red          # parse + validate every sample (headless)
red tests/check.red --pdf    # also render each sample to a temp PDF
```

## Layout

- `sampler.red` — the single entry point
- `sampler2.red` — edit-and-run sampler (double-click a sample to run the edited text; save variants as `*-mod.red`)
- `samples/` — one file = one lesson (numeric prefix sets order)
- `assets/` — images shared by samples
- `libs/` — the six library files (parser, styles, view, pdf, pdf-kit, pdf-fonts)
- `tests/check.red` — headless parse/validate (optional PDF) over the samples
- `docs/report-syntax-spec.md` — the full syntax reference
- `docs/reboot-plan.md` — the reboot plan and the decisions taken

## License

MIT — see `LICENSE`.
