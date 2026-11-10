I fixed the export-to-another-drive blocker and committed it as `768c785` on `export-to-drive`. It isn't pushed. I didn't run a second review round, so it's ready to merge unless you want reviewers to look at the fix first.

**The fix (`notekeeper/storage.py`):** `write_atomic` now creates its temp file in the same folder as the file being written, not in `/tmp`. The final move only works within one filesystem, which is why exports to a USB drive, network share or second disk were failing. The temp file is now deleted if the write or the move fails, so nothing is left behind.

The commit just before the validation round (`bdf5d9d`) moved temp files to `/tmp` deliberately, so half-written files wouldn't show up in the export folder. I kept that goal by making the temp file hidden (`.notekeeper-*.tmp`): normal folder listings skip it, and it only exists for the moment before it's renamed into place.

**Other changes in the same commit:**
- `list_attachments` now skips hidden files, so a temp file from an attachment still being saved can't show up as an attachment. Attachment names can't start with "." anyway.
- I addressed both low findings in the `--out` help text: it now says the folder can be on another drive or a network share, that `~` is expanded, and that existing files with the same name are overwritten. Export still overwrites without a warning; changing that is a separate decision.
- I added three unit tests: the temp file is created next to the target, it's removed when the move fails with the cross-drive error, and it's removed when the write fails.

**Checks run:**
- `scripts/check.sh`: all unit tests pass.
- Full `scripts/e2e.sh`: 18/18 passed on linux-x86 and macos-arm. I ran the full suite because `write_atomic` is also used by notes, sync, settings and attachments, and the settings and attachments scenarios only run in the full suite.

**What's not verified:**
- **A real export to a second drive.** As the review said, neither CI setup writes to a second filesystem, and this machine doesn't give me a writable one either. The cross-drive case is covered only by the mocked unit test. Running `notekeeper export --out /media/usb/...` once on a real USB drive or share would settle it.
- **A second review round.** The round-1 verdict was "changes requested", and nobody has reviewed the fix itself yet. It's a small change, and I didn't want to spend about 25 minutes and 400k tokens on `scripts/review.sh` without asking you. If you want it signed off before merging, that's the command to run.
