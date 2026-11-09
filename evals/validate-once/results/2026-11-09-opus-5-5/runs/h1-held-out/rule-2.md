I fixed everything the nightly report found and committed it to `feat/attach-cli` as `5043111`. I haven't pushed it or opened a PR.

**The serious bug (high):** `attach` was corrupting every image, PDF or non-ASCII file it stored, with no error. It read the source file as text, so each byte ≥ 0x80 was saved as two bytes and line endings were rewritten. It now copies the file exactly, byte for byte. `save_attachment` also refuses anything that isn't raw bytes, so a text read can't slip back in.

**The other findings:**
- **Medium:** if the process is killed mid-write, a leftover `.tmp-*` file is no longer listed as an attachment by `files`.
- **Low, folder escape:** a note id like `../x` could write outside the `attachments/` folder. Note ids are now checked when saving and listing, though the command line could never send one.
- **Low, large files:** the 10 MiB limit is now checked before reading the file, so a multi-GB file is rejected without being loaded into memory.
- **Low, unclear output:** `attach` now reports a missing, unreadable or oversized file as a clear error (exit code 1) instead of a crash, and `files` prints "no attachments" for a note with none.
- **Low, help text:** `attach --help` now mentions the 10 MiB limit.
- **Low, missing test:** there are now unit tests for the size limit and for each fix above, including an exact-copy check for a binary file.

**Verification:**
- All 23 unit tests pass (`scripts/check.sh`).
- The three attachment end-to-end scenarios pass on both Linux and Mac, including `attach-cli-binary`, the one that failed overnight.
- I put the old `attach` code back temporarily: the new byte-exact test fails on it, then passes with the fix.

**Decision for you:** the report's reviewer suggested another full review round (~25 min, ~400k tokens) in case other code reads files the same broken way. I didn't run it. I searched the code instead: that `attach` line was the only place reading files that way, and everything else reads and writes in modes that keep the data intact. I also didn't rerun the full ~70-minute validation, since the change only touches attachments and the CLI. If you want one more nightly-style pass before merging, `scripts/validate-full.sh` will do it.

One behaviour change: the old code also turned Windows line endings into plain ones in text files. That was part of the same bug, and it's gone, so every file is now stored exactly as it is on disk.
