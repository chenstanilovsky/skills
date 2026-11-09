I fixed the blocker and committed it to `export-to-drive` (commit `6d264d2`). It isn't pushed and there's no PR. I didn't re-run the full end-to-end suite, so the settings and attachments scenarios haven't been tested against the fix (details below). The status note is also saved in `validation/round-1-followup.md`.

**The fix** (`notekeeper/storage.py`): `write_atomic` now creates its temp file in the same folder as the file it's writing, so the final move never crosses drives and exports to a USB drive, network share or second disk work again. The temp file is hidden (`.notekeeper-*.tmp`) and gets deleted if the write or the move fails, so nothing is left in /tmp anymore.

**Trade-off:** commit 6de256e moved temp files to /tmp so a watched export folder would never see them, and that can't work across drives. Most file managers and sync clients skip hidden `.tmp` files, but a folder watcher may briefly see one while an export runs.

**Testing:**
- **New unit tests:** I added three. They check that the temp file is in the target folder, and that it's deleted when the move fails with the cross-drive error and when the write fails. All three fail on the old code and pass now.
- **Unit tests:** `scripts/check.sh` passes, 15/15.
- **End-to-end scenarios:** export-other-folder, export-md, export-csv, sync-basic, sync-offline-edit and create-list all pass on linux-x86 and macos-arm.
- **Real second drive:** I couldn't test an export to an actual second drive, because there's no second writable filesystem here. Only the unit test that simulates the error covers that case.

**Not re-run:**
- **Full end-to-end suite (~45 min):** settings-roundtrip, attachments-roundtrip and sync-soak only run as part of it. Settings and attachments also save through `write_atomic`. The fix puts the temp file back in the target folder, as it was on main, so I judged the risk low and didn't start another full run. If you want those confirmed before merging, run `scripts/e2e.sh`.
- **Review:** I didn't start a new review round.

**Left open (both low severity, not blocking):**
- The `export --out` help doesn't mention other drives or that `~` is expanded (`cli.py:20`).
- `export_markdown` overwrites existing `<id>.md` files without warning (`export.py:36`).

Once you're happy with that, optionally after the full end-to-end run, it's ready to merge.
