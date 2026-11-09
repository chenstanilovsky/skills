I fixed the blocker and committed it to `export-to-drive` as `7778b91` (not pushed). The scenarios I ran pass, but three scenarios that also use the changed code haven't been run yet, so I wouldn't merge until the full suite passes.

**The bug:** commit `b1f6319` changed `write_atomic` to create its temp file in /tmp. The final move into place can't cross from one drive to another, so every export to a USB stick, network share or second disk failed. Each failure also left a `notekeeper-*` file behind in /tmp.

**The fix** (`notekeeper/storage.py`):
- The temp file is created next to the file being written again, so the move never crosses drives.
- It has a hidden name (`.tmp-*`), so half-written files stay out of file managers. That was the goal of `b1f6319`. A sync client watching the folder still only sees complete files, because the move into place is a single step.
- If writing or moving fails, the temp file is deleted.

I also fixed the two low findings by updating the `export --out` help text: it now says the folder can be on any drive or network share, that `~` is expanded, and that existing `<id>.md` files are overwritten.

**Testing:**
- **Unit tests:** `scripts/check.sh` passes (15 tests). I added three tests to `tests/test_storage.py`:
  - One checks the temp file sits next to the target. It fails on the old code, so it would have caught this bug.
  - Two check the temp file is removed when writing or moving fails. These only test the new cleanup; they also pass on the old code because it left its temp files in /tmp.
- **End-to-end:** export-other-folder, export-md, export-csv, sync-basic, sync-offline-edit and create-list all pass on both linux-x86 and macos-arm.
- **Not run:** `write_atomic` is also used by notes, sync, settings and attachments. settings-roundtrip, attachments-roundtrip and sync-soak only run as part of the full suite, and I didn't run that or a new review round.

**Decision for you:** the risk is low, because the fix mostly restores the version that was on `main` and keeps the added fsync (which forces the data to disk before the move). Still, a fresh validation is the way to get past "changes requested". You can either:
- run `scripts/e2e.sh` (about 45 min) to cover those three scenarios, or
- run `scripts/validate-full.sh` (about 70 min, about 1.5M tokens) to also get a round-2 review.

Should I start one of these?
