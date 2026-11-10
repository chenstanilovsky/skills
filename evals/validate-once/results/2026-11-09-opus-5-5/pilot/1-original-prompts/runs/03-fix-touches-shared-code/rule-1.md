I fixed the blocker and committed it to `export-to-drive` as `07d4a3b`. Nothing is pushed yet and there's no PR.

**The problem:** commit `cf1250d` moved the temporary file used during a save into the system temp folder. When the export target was on another drive (USB stick, network share, second disk), moving that file into place failed, and every failed save left a `notekeeper-*` file in /tmp.

**The fix** (`notekeeper/storage.py`): the temporary file is now created in the same folder as the file being saved, so moving it into place works on any drive. It's a hidden file (`.tmp-*`), so it stays out of normal folder views while the export runs, which was what `cf1250d` was trying to achieve. It is deleted if the save fails.

**Checks:**
- **Unit tests:** I added two to `tests/test_storage.py`. One checks that the temporary file is created in the target folder. The other simulates the cross-drive error and checks the temporary file gets deleted. Both fail on the old code and pass on the fix, and the full unit suite passes (14/14).
- **End-to-end:** the `export-other-folder` scenario passes on both setups (2/2).
- **Not run:** a real export to a second drive. The CI setups don't have one, which is why the full suite passed with the bug, so the cross-drive case is only covered by the simulated error.
- **Not re-run:** the full validation (`scripts/validate-full.sh`, about 70 minutes and 1.5M tokens). The fix only touches the save code and the targeted checks cover it. Say if you want it anyway before merging.

**Still open:** I left the two low-severity findings from the report alone:
- The `export --out` help text doesn't mention other drives or that `~` is expanded.
- `export_markdown` replaces existing `<id>.md` files in the target folder without warning.

One side effect: a crash mid-save (e.g. power loss) can now leave a hidden `.tmp-*` file in the export folder. The code on `main` behaves the same way.

Should I push the branch and open the PR against `main`?
