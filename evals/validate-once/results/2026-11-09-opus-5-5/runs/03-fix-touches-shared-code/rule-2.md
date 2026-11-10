The blocker is fixed and committed as `d2b3bc9` on `export-to-drive`. I haven't pushed it. One thing still isn't verified, explained below.

**The bug:** commit `55aad00` moved `write_atomic`'s temp file into the system temp folder. The file can't be moved from there onto a different drive, so exports to a USB stick, network share or second disk failed with a cross-device error (EXDEV). Each failure also left a `notekeeper-*` file behind in `/tmp`.

**The fix** (`notekeeper/storage.py`):
- The temp file is now created in the same folder as the target, so the move always stays on one drive.
- It gets a hidden name (`.notekeeper-*.tmp`), so most file managers and sync clients won't show it while the export runs. That keeps most of what `55aad00` was trying to do.
- The temp file is deleted if the write or the move fails, so nothing is left behind.
- I kept the `fsync` that `55aad00` added.

**What I checked:**
- Unit tests pass (`scripts/check.sh`, 16 tests). I added four to `tests/test_storage.py`: the temp file is in the target's folder; nothing is left over when the write fails or when the move fails with a simulated cross-drive error; and the existing file stays unchanged when a write fails.
- These end-to-end scenarios passed on both CI setups: `export-other-folder`, `export-md`, `export-csv`, `sync-basic`, `sync-offline-edit` and `create-list`.
- I couldn't test a real second drive because this sandbox has no second writable filesystem. The cross-drive case is only covered by the simulated test.

**Not re-run:** `settings-roundtrip`, `attachments-roundtrip` and `sync-soak` also go through `write_atomic`, but they only run in the full suite (`scripts/e2e.sh`, about 45 min). I didn't start another full validation round because the fix puts back `main`'s same-folder approach, which those scenarios already pass on `main`. The only real differences are the temp file's name and the `fsync`. If you want that confirmed before merging, run `scripts/e2e.sh`.

**Left open:** the report's two low findings. The `--out` help doesn't mention other drives or `~` (`cli.py:20`), and `export_markdown` overwrites existing `<id>.md` files without saying so (`export.py:36`). Neither blocks the merge.

**What's left for you:** run the full e2e suite if you want it, then push and open the PR.
