The export-to-drive branch is ready to merge with a few known limits. The blocking bug is fixed and committed as `6cc8ffe`. I didn't push or open a PR. I also wrote a note on where it stands at `validation/status.md`.

**What was wrong:** when exporting, notekeeper first writes each file to a temporary file, then moves it into place. Commit 45c7c19 started putting that temporary file in /tmp. A file can't be moved from one drive to another that way, so every export to a USB drive, network share or second disk failed. Each failed export also left a `notekeeper-*` file behind in /tmp.

**Fix (`notekeeper/storage.py`):** the temporary file now goes in the same folder as the export, as a hidden file named `.notekeeper-*.tmp`. It is deleted if the write or the move fails.

**Checks run on the fix:**
- I added three unit tests in `tests/test_storage.py`: one simulates exporting to another drive, and two check that the temporary file is deleted when the write or the move fails. All three fail on the old code and pass now.
- The full unit test suite passes (15/15).
- Three end-to-end scenarios pass on both test setups (6/6): export-other-folder, export-md and sync-basic.

**Trade-off to look at:** 45c7c19 moved the temporary file out of the export folder so that a sync client or file manager watching that folder wouldn't see half-written files. That can't work across drives. Making the file hidden keeps most of that benefit, but a sync client that syncs hidden files could briefly see it. `main` had the same exposure.

**Not run:**
- The full review and end-to-end run (~70 min, ~1.5M tokens). The fix puts the temporary file back where `main` had it, and `main` passed that run.
- The settings and attachments scenarios. They use the same code but only run as part of the full suite.
- No automated test writes to a real second drive, so that case is only simulated. A quick manual export to a USB stick or network share before merging would confirm it.

**Not fixed (both low priority from the review):**
- The `--out` help text doesn't say the folder can be on another drive or that `~` is expanded.
- Exporting to Markdown overwrites existing `<id>.md` files in the export folder without saying so.
