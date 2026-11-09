I fixed the blocker. The `export-to-drive` branch is ready to merge with one known limit, though I couldn't test a real export to a second drive (details below).

**The blocker:** exports to a USB drive, network share or second disk failed with "Invalid cross-device link". The temp file was being written to `/tmp`, and a file can't be renamed from one drive to another. Each failure also left a `notekeeper-*` file behind in `/tmp`.

**Fixed** in commit `cb804bb`:
- **The blocker:** `write_atomic` (`notekeeper/storage.py`) now writes its temp file as a hidden `.notekeeper-*.tmp` in the same folder as the target, then renames it into place. The flush-to-disk step from your branch is kept, and the temp file is deleted if the write or the rename fails. On main the temp file was already in the same folder, so for every other user of this function (notes, sync, settings, attachments) the only change from main is the temp file's name.
- **New tests** in `tests/test_storage.py`:
  - the temp file is created in the target folder;
  - a simulated cross-device rename failure leaves nothing behind in the target folder or `/tmp`;
  - a failed write keeps the old file and leaves no temp file.
  
  The first two failed on the old code and pass now.
- **Low finding, help text:** `export --out` help now says the folder can be on another drive or a network share and that `~` is expanded.

**Checks run, on the final commit:**
- `scripts/check.sh`: 15/15 unit tests pass.
- `scripts/e2e.sh --scenario export-other-folder`: 2/2 passed (linux-x86, macos-arm).
- Round 1's review and full e2e suite ran on the version before this fix.

**Known limits (not fixed):**
- **Overwrites without warning:** `export_markdown` replaces existing `<id>.md` files in the target folder without saying so (low finding). Main did the same, and choosing between a warning, a `--force` flag or skipping the files is your call.
- **Temp files visible during writes:** while a write is in progress, the hidden temp file sits in the target folder. A sync client could notice it, and `list_attachments` could list it during a save. Main behaved the same way. Your branch's plan to keep temp files out of the target folder can't work for exports to another drive.

**Not tested:**
- **Real second-drive export:** I couldn't run one. This machine has only one disk I can write to, and neither CI setup has a second one, so the cross-device case is covered only by the simulated unit test. Before merging, it's worth running `python3 -m notekeeper.cli export --out /media/usb/notes` once against a real USB drive or share.
- **Second full validation:** I didn't re-run `validate-full.sh` (about 70 minutes and 1.5M tokens). The fix brings `write_atomic` back to how main already worked, and the tests above cover it. Run it if you want the settings and attachments scenarios (full suite only) re-checked anyway.

I haven't pushed or opened a PR. The commit is only on your local `export-to-drive` branch.
