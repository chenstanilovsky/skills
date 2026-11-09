I fixed the blocker and committed it to `export-to-drive` as `056490f`. Unit tests and the full end-to-end suite pass, but I couldn't test a write to a real second drive here, and I haven't pushed, merged or re-run the review round.

**The fix (`notekeeper/storage.py`).** `write_atomic` now creates its temp file in the same folder as the file it's writing, not in the system temp folder. A file can't be renamed across drives, so exports to a USB drive, network share or second disk now work. The temp file is still fsynced, and it's removed if the write or the rename fails, so nothing is left behind in `/tmp` or the export folder. To keep the goal of `ac64399`, the temp file is hidden (`.notekeeper-tmp-*`), so it stays out of normal folder views during the write. The catch: a sync client or a file manager set to show hidden files could still see it for a moment. The alternative, keeping it outside the folder, is what broke exports to other drives.

**Tests:** I added three unit tests in `tests/test_storage.py`:
- the temp file is created next to the file being written;
- the temp file is removed when the rename fails with a cross-drive error;
- if a write fails, the existing file is left as it was.

The first two fail on the old code and pass on the fix.

**The two low findings:** I covered both in the `export --out` help text. It now says the folder can be on another drive or a network share, that `~` is expanded, that missing folders are created, and that existing files are overwritten. Export still overwrites files without warning; I only documented it.

**Validation:**
- `scripts/check.sh`: all 15 unit tests pass.
- `scripts/e2e.sh`, the full suite: 18/18 pass on linux-x86 and macos-arm. I ran the full suite rather than single scenarios because `write_atomic` is also used by notes, sync, settings and attachments, and the settings and attachments scenarios only run in the full suite.

**Still open:**
1. **No real cross-drive test.** This sandbox has no second writable filesystem, so I tested the cross-drive case with a simulated error. The e2e suite doesn't cover it either, which is why round 1 missed it. One manual export to a USB drive or share would settle it.
2. **No new review round.** `scripts/review.sh` costs about 25 minutes and 400k tokens. The fix is small and mostly puts back how `write_atomic` worked on `main`, so I left that call to you.
3. **Merge.** If you're happy with both, the branch is ready to merge.
