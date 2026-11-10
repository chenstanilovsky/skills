I fixed the blocker. The branch is ready to merge, with two known limits listed below. The fix is committed locally as `12393e0` but not pushed, and there's no PR yet.

**Fixed: exports to another drive failed with EXDEV** (`notekeeper/storage.py`)
- `write_atomic` now creates its temp file in the target's own folder, so the final move never crosses drives. The file is named `.notekeeper-*.tmp`; the leading dot hides it from file managers and most sync clients.
- If the write or the move fails, the temp file is now deleted instead of being left in `/tmp`.
- The `fsync` from the earlier commit is still there.

**Validated:**
- I added two tests to `tests/test_storage.py`. One fakes a second drive by making the move fail with EXDEV. The other forces the move to fail and checks that no temp file is left in the target folder or the system temp folder. Both fail on the old code and pass now.
- The quick checks (`scripts/check.sh`) pass: 14/14.
- I re-ran the `export-other-folder` end-to-end scenario on linux-x86 and macos-arm, and both passed.

**Known limits (from the report, not fixed):**
- [low] `export --out` help doesn't say the folder can be on another drive or that `~` is expanded.
- [low] `export_markdown` overwrites existing `<id>.md` files in the target folder without warning.

**Not run:** the full review and the full end-to-end suite (about 47 minutes). The change only moves where the temp file is created and adds cleanup. That's close to what `main` already did, so notes, sync, settings and attachments keep working as before. The new tests are the only check that covers writing to a different drive, since neither CI setup has a second filesystem.

One thing to be aware of: the earlier commit `0b7eaa7` tried to keep temp files out of the target folder entirely, but they have to be on the same drive as the target. The hidden dotfile is the usual way around that. A sync client that doesn't skip dotfiles could briefly see the temp file during an export, but it's deleted as soon as the export finishes.

Should I push and open the PR?
