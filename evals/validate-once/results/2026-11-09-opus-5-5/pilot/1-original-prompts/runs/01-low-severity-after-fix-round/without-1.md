I fixed two of the three round 2 findings and left the third alone on purpose. The branch looks solid, but it hasn't had a third full validation round, because that run is expensive.

**Round 2 findings (all low severity):**
- **R2-3, `--out` help text:** fixed. `export --help` again says "output directory (md) or file (csv)".
- **R2-2, Excel shows non-ASCII text as garbage:** fixed with a new opt-in `--bom` flag. It adds a UTF-8 byte-order mark at the start of the CSV so Excel on Windows reads `Café`, `Grüße` and emoji correctly. I didn't make it the default: scripts and `csv.reader` reading the file as plain UTF-8 would then see a stray character at the start of the first column name (`id`). That includes our own e2e scenario. I added an example to the README.
- **R2-1, CSV column names (`tags`) vs the Markdown label (`Tags:`):** not changed. The lowercase CSV names are also the values `--fields` accepts, and anyone with an existing import would break if they changed. It's a style choice, so I think it's yours to make. If you want one convention, I'd change the Markdown label rather than the CSV columns.

**Checks run:**
- `scripts/check.sh`: all 18 unit tests pass. Four are new: no byte-order mark by default, `--bom` writes one and the file still reads back correctly, the CLI flag works, and the help text.
- `export-csv` and `export-csv-quoting` e2e scenarios: 4/4 pass on linux-x86 and macos-arm.
- Not run: `scripts/validate-full.sh` (~70 min, ~1.5M tokens). The round 2 report asks for a full re-run. Since everything left was low severity and the changes are small and only touch export, I didn't start it without asking. Say the word and I'll run it.

The changes are committed on `csv-export-polish` as `2c1c118` and not pushed.
