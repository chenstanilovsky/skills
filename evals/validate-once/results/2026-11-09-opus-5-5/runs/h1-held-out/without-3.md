I fixed all 7 findings from the validation report and committed them to `feat/attach-cli` as `d329d59`. Nothing is pushed or merged. The fixed failing test and the other two attachment tests now pass on both setups, but I didn't re-run the full test suite or another review round (more on that below).

**The serious bug: `attach` was corrupting files.** It read the file as text and saved it re-encoded, so any image, PDF or non-ASCII file came out about 1.5× bigger and wouldn't open. Windows line endings were also converted. There was no error message.
- `attach` now reads the file as raw bytes and stores it exactly (`notekeeper/cli.py:65`).
- `save_attachment` now refuses text input, so this can't come back through another caller.
- **Files attached with the old code are still corrupted.** If anyone has used `attach` on a binary or non-ASCII file, those copies need to be re-attached from the originals.

**The other six findings:**
- **Size limit:** `attach` now checks the 10 MiB limit before reading the file and never reads more than limit + 1 byte. Files that are too big or can't be read give a clear error and exit code 1 instead of a traceback.
- **Leftover temp files:** `files` no longer lists the `.tmp-*` files left behind when a save is interrupted.
- **Note IDs:** `note_id` is now checked the same way as attachment names, so `../x` and similar are rejected.
- **Empty notes:** `files` prints "no attachments" when there are none.
- **Help text:** `attach --help` now mentions the 10 MiB limit.
- **Tests:** I added unit tests for the size limit, binary and line-ending round-trips through the CLI, the new checks, and the error cases. Run against the old code, 9 of the 16 attachment and CLI tests fail. Run against the fix, all 25 unit tests pass.

**What I ran:** the fast checks (`scripts/check.sh`) and the three attachment scenarios: `attach-cli-binary` (the one that failed), `attach-cli` and `attachments-roundtrip`. All pass on linux-x86 and macos-arm.

**What I skipped, and why:**
- **The full e2e suite (~45 min):** the other 7 scenarios cover add, list, export, sync and settings, and I didn't change that code. The only edits are in the attachment module and the attach/files commands.
- **The extra full review round the report suggested (~25 min, ~400k tokens):** its concern was that other parts of the CLI might read files the same way. I checked, and `attach` is the only place that reads a user's file; everything else reads JSON, which is decoded correctly.

Since you want this one solid, it's reasonable to run `scripts/validate-full.sh` once more before merging (~70 min). I can start it if you'd like.

There are some untracked dotfiles and editor folders in the working directory (`.bashrc`, `.claude/`, `.idea`, etc.) that weren't part of this work. I didn't commit or touch them.
