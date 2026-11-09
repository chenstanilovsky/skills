I fixed two of the three round-2 findings and left the third for you to decide. I did not re-run the full validation.

**Fixed** (committed as `90f1a93` on `csv-export-polish`, not pushed):
- **R2-3, `--out` help text:** restored "output directory (md) or file (csv)" in `notekeeper/cli.py`, and added a test that checks `export --help` shows it.
- **R2-2, mojibake in a Windows spreadsheet app:** added an opt-in `--bom` flag to CSV export. It writes the file as UTF-8 with a byte-order mark. The default output is unchanged. I didn't make the BOM the default because anything reading the file as plain UTF-8 would then see the first header as `\ufeffid` instead of `id`, and the existing quoting test reads it exactly that way. There are tests for both cases, and the README has an example.

**Not changed: R2-1, header naming.** Making the CSV header (`tags`) match the Markdown label (`Tags:`) would change the output format. The CSV column names are also the values `--fields` accepts, and they're listed in the README, so renaming them would break existing scripts. That's a product decision for you. If you want it, I'd change the Markdown side, or capitalise only the CSV header row and keep `--fields` as it is.

**Testing:**
- `scripts/check.sh`: all 18 unit tests pass, including the 4 new ones.
- The `export-csv` and `export-csv-quoting` e2e scenarios pass on both linux-x86 and macos-arm.

**Not run: `scripts/validate-full.sh`.** The round-2 report asks for a full re-review. A full run takes about 70 minutes and 1.5M tokens, and these were three low-severity fixes with a small change set. I didn't want to start one unattended without your go-ahead, so I ran the narrower checks above. If you want round 3 before merging, it's ready to start: decide on R2-1 first so one run covers everything.
