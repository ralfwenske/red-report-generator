# Report Generator Sampler — User README

## Purpose

`red-view sampler.red` opens the **Report Generator Sampler**, an interactive tool for exploring the report generator library and experimenting with its declarative report syntax. It serves two goals:

1. **Show many uses of the report generator** — browse the built-in samples, each demonstrating a different feature.
2. **Let you experiment yourself** — edit any sample's code, save it as a variant, and immediately re-render the report to see the effect.

The sampler is an *edit-and-run* tool: it loads each sample in its own context, so your changes do not affect other samples or the sampler itself.

---

## Running the Sampler

```bash
red-view sampler.red
```

The GUI build (`red-view`) is required. The sampler will try to locate the `samples/` directory relative to its own file.

Once the window opens, you will see:

- **Left pane:** a list of all `samples/*.red` files, sorted by filename.
- **Right pane:** a source code area showing the currently selected sample.
- **Button row:** a small toolbar with several action buttons.

Close the sampler's window to return to the shell.

---

## Interacting with the Sampler

### Browsing samples

Click any sample name in the left list. Its source text appears in the right pane.

### Rendering a report

After selecting a sample, click **"Render Report"**. The sampler will:

1. Change the working directory to the sample's directory so that relative paths resolve correctly.
2. Load the sample's text into a fresh context.
3. Call the sample's `show-report` function.
4. If the report parses and validates successfully, the View window for that report opens.
5. When you close the View window, the sampler resumes.

If the sample produces a validation or runtime problem, the sampler captures the returned message and displays it in a popup.

### Working with modified samples

The source area has a subtle behavior: whenever the source pane has keyboard focus, the sampler marks the sample as *modified*.

When you click **"Render Report"** while a sample is marked as modified, the sampler will save the modified text as a **`-mod.red` variant** (e.g., `010-hello-mod.red`). The original file is left untouched.

If you are already editing a `-mod.red` variant, it saves in place.

### Buttons reference

| Button | Behavior |
|---|---|
| **Render Report** | Renders the currently selected sample. Saves as `-mod.red` if the original was modified. |
| **Replace Original** | Overwrites the original `.red` file with the current source text, then deletes the corresponding `-mod.red` variant. |
| **Create -mod file** | Manually save the current source text as a `-mod.red` variant, without rendering. |
| **Quit** | Closes the sampler and returns to the shell. |

---

## Adding a New Sample

1. Copy `samples/000-template.red` to a new file with the next numeric prefix (e.g., `samples/011-my-sample.red`).
2. Keep the sample focused on one idea.
3. Update the `Title` and `Demo` fields in the header block.
4. The numeric prefix determines the sort order in the list.

---

## Understanding a Sample's Structure

Every sample follows this contract:

```red
Red [
    Title: "010 — Hello"
    Demo:  "BODY plus one line: the minimum viable report"
    Level: 1
    Needs: 'View
]

report: [
    [BODY [
        ["Hello World" [h2 purple]]
    ]]]
]

#include %../libs/report-view.red

error-msg: show-report report "01 — Hello"
if error-msg <> "" [alert error-msg]
```

Key points:

- **`Title` / `Demo` / `Level` / `Needs`** are metadata fields.
- **`report`** is the actual report block, composed of sections: `HEADER`, `BODY`, `FOOTER`.
- Each line is a value followed by optional style pairs.
- Shared images are referenced from a sample as `%../assets/<name>.jpg`, relative to the sample's directory.

---

## Experimenting Yourself

1. Select any sample from the list.
2. Click in the source pane to give it focus (this marks the sample as modified).
3. Edit the text.
4. Click **"Create -mod file"** to save the edited version as a variant.
5. Click **"Render Report"** to see the rendered output.
6. Close the report window to return.

When you are done:
- If you want to keep your changes as a separate lesson, leave the `-mod.red` file in place.
- If you want to overwrite the original sample, click **"Replace Original"**.

---

## Checking the Project

Outside the GUI:

```bash
red tests/check.red          # parse + validate every sample (headless)
red tests/check.red --pdf    # also render each sample to a temporary PDF
```

---

## Summary of Actions

| Action | How |
|---|---|
| Browse all samples | Click sample name in left list |
| Render a sample's report | Click "Render Report" |
| Edit a sample's source | Click in source pane, then type |
| Save edits as a variant | Click "Create -mod file" |
| Overwrite the original | Click "Replace Original" |
| Close the sampler | Click "Quit" |
| Add a new sample | Copy `000-template.red`, rename with next numeric prefix |
| Run headless checks | `red tests/check.red` |

This sampler is both a tutorial and a playground: explore the samples to learn the report generator's syntax, then modify them to see how the layout and rendering respond to your changes.
