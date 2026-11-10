The CSV export is ready to merge. I fixed the one small regression from round 2 and left the other two findings for you, because each changes the file format. I didn't start a round 3. The note is in `validation/STATUS.md`.

**Checks run:**
- Round 2 tested commit `42fe209`. All 18 end-to-end tests passed on linux-x86 and macos-arm, and the reviewers confirmed all four round 1 fixes.
- After my fix, the unit tests pass (14 tests) and `export --help` shows the restored text.

**Fixed:**
- **R2-3:** the `--out` help text says "output directory (md) or file (csv)" again (`a87e6a5`). Only help text changed, so the unit tests were the right check.

**Not fixed, your call:**
- **R2-1, header naming:** the CSV header is `id,title,body,tags,updated_at`, while the Markdown export labels the same field `Tags:`. Renaming the columns would break anything that already reads the CSV, and the README and `--fields` use these names. I'd keep them.
- **R2-2, no byte-order mark:** one Windows spreadsheet app garbles non-ASCII titles (`Café`, emoji) in CSV files without a byte-order mark. Adding the mark by default would fix that app but put a stray character in front of the first header for many other CSV readers. If you want it, I'd make it an opt-in `--bom` flag and run just the two CSV end-to-end scenarios (about 6 minutes).

**Not run:**
- **Round 3 of `scripts/validate-full.sh` (about 70 minutes, 1.5M tokens):** the report says to re-run it. But round 2 found nothing above low severity, and the only change since is one help string, so another round wouldn't test anything new. If you still want it, it's one command.

I made two commits on `csv-export-polish`: the fix (`a87e6a5`) and the status note (`7222125`). Nothing is pushed. `git status` also lists some untracked config files (`.bashrc`, `.idea`, `.claude/`, etc.) that I didn't create, and I left them alone.
