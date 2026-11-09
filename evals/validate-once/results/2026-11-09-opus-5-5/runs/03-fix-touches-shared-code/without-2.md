I fixed the blocker from round 1 and committed it to `export-to-drive` as `b62a6d3`. Unit tests and the full end-to-end suite pass. I haven't pushed, opened a PR or merged; that's yours to do.

**The blocker:** the temp file used to be created in the system temp folder, so exporting to a different drive failed when the finished file was moved into place. `write_atomic` (`notekeeper/storage.py:7`) now creates a hidden `.notekeeper-*.tmp` file in the target folder and deletes it if the write or move fails. On that drive, a failed export leaves the old file as it was and no leftover temp file.

**A trade-off from ef98c3e:** that commit moved temp files out of the target folder so a file manager or sync client watching the folder wouldn't see half-written files. That approach is what broke exports to other drives, since a file can't be moved between drives in one step. The leading dot hides the temp file in file managers and most sync clients, but a client that syncs hidden files could still briefly see one. Writing next to the target is the only way to keep the write atomic, so I think this is the right call.

**The two low findings:** the help for `export --out` now says the folder can be on any drive or network share, that `~` is expanded, and that existing files are overwritten. I also added a docstring to `export_markdown` saying it replaces existing files. I didn't add a warning when it overwrites; tell me if you want one.

**Tests:**
- **New unit tests:** three tests in `tests/test_storage.py` check that the temp file is created next to the target, that it's removed on failure, and that a failed write keeps the old file. The temp-location test fails on the old code. `scripts/check.sh` passes all 15 tests.
- **End-to-end:** all 18 checks passed (9 scenarios on each of the 2 setups). I ran the whole suite rather than single scenarios because notes, sync, settings and attachments all use `write_atomic`, and the settings and attachments scenarios only run in the full suite.
- **What isn't tested:** I couldn't reproduce a real cross-drive export, because there's only one writable drive here and the CI setups don't have a second one either. The fix is covered by the unit tests, not by an actual export to a USB drive or network share.
- **Review round:** I didn't run `scripts/review.sh` (~25 min, ~400k tokens) for a fix this small. If you want reviewer sign-off before merging, run `scripts/review.sh` on its own.
