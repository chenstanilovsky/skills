I fixed the blocker and committed it to `export-to-drive` as `be7e029`. Nothing is pushed or merged. The fix is covered by unit tests and targeted end-to-end runs. The one thing I didn't run is the full validation, so whether to merge without it is your call.

**The bug:** commit `240144a` moved `write_atomic`'s temp file into the system temp folder. `os.replace` can't move a file from one drive to another, so every export to a USB drive, network share or second disk failed. Each failure also left a `notekeeper-*` file behind in /tmp.

**The fix** (`notekeeper/storage.py`):
- The temp file is now created in the target's own folder, so the move stays on one drive.
- It's named `.notekeeper-*.tmp`. The dot hides it, which keeps the goal of `240144a`: file managers and sync clients don't show half-written files.
- It's deleted if the write or the move fails, so nothing is left behind.
- The `fsync` that `240144a` added is kept.

**Checks:**
- **Unit tests:** `scripts/check.sh` passes, 14/14. Two new tests in `tests/test_storage.py` check that the temp file sits next to the target and that nothing is left behind (in the target folder or /tmp) when the move fails. Both tests fail on the old code. I had no second drive here, so the move failure is simulated in the test rather than reproduced.
- **End-to-end:** `export-other-folder`, `export-md`, `export-csv`, `sync-basic` and `sync-offline-edit` all pass on both linux-x86 and macos-arm.

**Not run:**
- **`settings-roundtrip` and `attachments-roundtrip`:** these also save through `write_atomic`, but they only run as part of the full ~45 min suite. I think the risk is low, because this restores how `main` already worked (temp file in the target folder) plus the cleanup and `fsync`.
- **Full validation (`scripts/validate-full.sh`):** a full round takes about 70 minutes and 1.5M tokens. If you want it, or just `scripts/e2e.sh` (the ~45 min end-to-end suite), before merging, run it tomorrow.

**Left for you:** the two low-severity findings from the report are unfixed:
- `cli.py:20`: the `--out` help doesn't mention other drives or `~` expansion.
- `export.py:36`: `export_markdown` silently overwrites existing `<id>.md` files.

Neither blocks the merge. The second one is really a question of what the behaviour should be (warn, skip, or overwrite), which is your decision.

Once you're happy with the above, the branch is ready to open a PR against `main`.
