I fixed the blocker and both low findings, and all tests pass, but I couldn't test an actual export to another drive. Everything is committed locally on `export-to-drive` and nothing is pushed. The note is in `validation/round-1-response.md`.

**The blocker:** exports to a USB stick, network share or second disk failed because the temp file was created in `/tmp`, and a file can't be moved across filesystems. Now `write_atomic` (`notekeeper/storage.py`) creates the temp file in the same folder as the target. It's a hidden file (`.notekeeper-*.tmp`), so file managers and sync clients still won't show half-written exports, which is what the earlier change was for. If the write or the move fails, the temp file is now deleted instead of being left behind.

**The two low findings:** the `--out` help text now says the folder can be on any drive, that `~` is expanded, and that existing files are overwritten.

**Testing:**
- **Unit tests:** 14/14 pass. I added two:
  - one checks that the temp file is created next to the target, and it fails on the old code.
  - one checks that a failed write leaves nothing behind and keeps the old file.
- **Full end-to-end suite:** 18/18 pass on both CI setups. I ran the full suite rather than single scenarios because settings and attachments use the same code and are only tested there.

**Before you merge:**
- **No real cross-drive test:** my sandbox has only one writable filesystem, and neither CI setup has a second one, which is why validation missed the bug. The new test checks where the temp file goes, not a real cross-drive move. Try one export to a USB stick or network share by hand.
- **No second review round:** a round costs about 25 min and 400k tokens, and the fix is small. If your merge process needs a reviewer to sign off, run `scripts/review.sh`.
- **No pull request yet:** I didn't push or open one.
