I've fixed the blocker. The branch is ready to merge, with two minor issues left as known limits. The fix is committed locally on `export-to-drive` (f3012f4); I haven't pushed or merged anything.

**The blocker:** this branch changed `write_atomic` to write its temp file in the system temp folder, then move it into the export folder. That move fails when the export folder is on a different drive, and each failed write left a `notekeeper-*` file behind in `/tmp`. The temp file now goes back next to the target, which is how it worked on `main`. It's a hidden `.tmp-*` file, so it still stays out of sight in file managers while the export runs. It gets deleted if the write or the move fails, and the `fsync` this branch added is kept.

**Validated:**
- **New tests:** I added three tests in `tests/test_storage.py`. They check that the temp file is created in the target's folder, and that it's removed when the move fails (simulated cross-drive error) or the write fails (simulated full disk). All three fail on the old code and pass with the fix.
- **Fast checks:** `scripts/check.sh` passes all 15 tests on the final commit.
- **End-to-end:** I re-ran only the two export scenarios, `export-other-folder` and `export-md`. Both passed on linux-x86 and macos-arm.

**Not run:**
- **Real cross-drive export:** the sandbox has no second writable filesystem, so I couldn't reproduce the original failure for real. The simulated test covers it, but a quick manual export to a USB stick or second disk would confirm it.
- **Another full review or full end-to-end run:** I didn't run either again. `write_atomic` is shared by notes, sync, settings and attachments, but the fix puts it back to how `main` already worked. Their tests and the round-1 run all passed on that version. The settings and attachments end-to-end scenarios only run in the full suite (~45 min), so I left that for you to decide.

**Also fixed:** the low finding about `export --out` help. It now says the folder can be on another drive or a network share and that `~` is expanded.

**Known limits (not fixed):**
- `export_markdown` overwrites existing `<id>.md` files in the target folder without saying so. That's a behaviour change worth discussing, not a blocker.
- `attachments.list` could briefly show a `.tmp-*` file if it runs during an attachment write. That's not new: `main` already worked this way.

Next steps are yours: push the branch and open the PR.
