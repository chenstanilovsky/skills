The blocker is fixed and export-to-drive is ready to merge, with two known limits. The fix is committed locally on the branch but not pushed. I didn't open a PR either; that's your call when you're back. The same note is in `validation/round-1-followup.md`.

**Fixed (commit ad6d495)**
- **Exports to another drive failed (`notekeeper/storage.py`):** `write_atomic` now puts its temp file in the target folder itself, as a hidden `.notekeeper-*.tmp`. Because it's on the same drive as the target, the final move works. If the write or the move fails, the temp file is deleted, so nothing is left behind in /tmp. I kept this branch's change that forces the data to disk before the move.
- **Tests:** I added two tests to `tests/test_storage.py`. Both failed before the fix and pass now. One checks that the temp file is created in the target folder. The other fakes the cross-drive error and checks that no temp file is left anywhere.
- **`export --out` help text:** it now says the folder can be on any drive and that `~` is expanded.

**Validated (on the fixed commit)**
- `scripts/check.sh`: 14/14 unit tests pass.
- End-to-end scenarios export-other-folder, export-md and sync-basic: 6/6 pass on both CI setups.

**Known limits (not fixed)**
- `export_markdown` still overwrites existing `<id>.md` files without a warning. It already did that, and those files are notekeeper's own exports, so I left it for a later change.
- While a write is in progress, the hidden temp file sits in the target folder. A sync client that shows hidden files could see it briefly. This is the standard way to make a write all-or-nothing, and main worked the same way before this branch.

**Not run**
- **An export to a real second drive.** My environment had no second drive I could write to, so the cross-drive case is only covered by the test that fakes the error. Neither CI setup covers it either. Worth running once by hand: `python3 -m notekeeper.cli export --out /media/usb/notes`.
- **A second review round and the full end-to-end suite (about 70 minutes).** The fix puts `write_atomic` back to how main did it. settings-roundtrip, attachments-roundtrip and sync-soak only run as part of the full suite, so they weren't re-run after the fix. If you want them covered before merging, run `scripts/e2e.sh` (about 45 minutes).
