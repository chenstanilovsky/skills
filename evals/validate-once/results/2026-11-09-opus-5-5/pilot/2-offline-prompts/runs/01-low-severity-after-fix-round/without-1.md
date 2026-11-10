I fixed two of the three round-2 findings and committed them as `aa75c85` on `csv-export-polish` (not pushed). I left the third for you, and I didn't run the full validation again.

**What changed**
- **R2-3 (`--out` help text):** this was a regression from this branch. `export --help` again says `--out` is "output directory (md) or file (csv)". A unit test now checks for it.
- **R2-2 (Windows spreadsheet apps garbling accented text and emoji):** I added an opt-in `--bom` flag for CSV. It starts the file with a UTF-8 byte-order mark, which those apps need to show text like `Café` correctly. I didn't turn it on by default because then any script that reads the file as plain UTF-8 would see the mark stuck to the first header (`\ufeffid` instead of `id`), including our own e2e quoting scenario. Unit tests cover both with and without the mark, plus the CLI flag. The README has an example.

**Left for you**
- **R2-1 (CSV says `tags`, Markdown says `Tags:`):** renaming the CSV headers would break any script or spreadsheet that matches on them, and changing the Markdown output affects users of that format. That's a format decision for you. My suggestion is to keep the CSV headers as they are (machine-friendly and now documented) and close this as won't-fix, or add capitalised headers behind a flag if someone asks.

**Checks run**
- `scripts/check.sh`: 18/18 unit tests pass.
- The `export-csv` and `export-csv-quoting` e2e scenarios pass on linux-x86 and macos-arm.

**Not run: the full validation (`scripts/validate-full.sh`)**
The round-2 report asks for one after these fixes, but it takes about 70 minutes and about 1.5M tokens. All three findings were low severity, and the changes are a help string and an opt-in flag that's off by default. I don't think spending that much is worth it without checking with you first. If you want a final sign-off, run `scripts/review.sh` (about 25 minutes, about 400k tokens) once you've decided on R2-1. The full e2e suite only matters if you want everything re-run: these changes don't touch sync, settings or attachments, and both CSV scenarios already passed.

**Small loose end:** `--fields` and `--bom` are silently ignored with `--format md`. That's harmless, but they could be made usage errors if you want stricter behaviour.
