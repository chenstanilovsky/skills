I fixed all 7 findings from `validation/round-1.md` and committed them on `feat/attach-cli` as `3168c42`. I didn't push or merge.

**Fixed:**
- **High: binary files were stored corrupted.** `attach` now reads the file as raw bytes, so images and PDFs are stored exactly as they are. `save_attachment` also raises an error if it's given text instead of bytes, so this can't come back silently.
- **Medium: `files` listed leftover temp files.** Files that start with `.tmp-` are now skipped.
- **Low items:**
  - A `note_id` like `../x` is now rejected, so attachments can't be written outside `attachments/`.
  - Files over 10 MiB are rejected before being read. An oversized or unreadable file now gives a clear error and exit code 1 instead of a traceback.
  - `files` prints "no attachments" when a note has none.
  - `attach --help` mentions the 10 MiB limit.
  - New unit tests cover the size limit, temp files, bad note ids, and byte-for-byte storage of a file with CR/CRLF and every byte value.

**Checked:**
- All 22 unit tests pass.
- I re-ran only the attachment end-to-end scenarios, and all pass on both setups: `attach-cli-binary` (the one that failed), `attach-cli` and `attachments-roundtrip`.

**Not run:** the full validation (~70 min, ~1.5M tokens). The reviewer suggested another full round in case other CLI code reads files the same broken way. I searched the code for that instead: the attach command was the only place reading a file that way, since export, sync and settings write through the binary-safe helper. With that answered and the failing scenario now passing, another full run didn't seem worth the cost. It's your call: if you want the full suite before merging, run `scripts/validate-full.sh`, or just `scripts/e2e.sh` (~45 min) to skip the review agents.

**Known limits, not fixed:**
- If two files with the same name are attached to one note, the second quietly replaces the first, which was already the behaviour.
- A temp file left by a crash is now hidden from `files`, but it stays on disk.

There are some untracked files in the working directory (`.bashrc`, `.idea`, `.mcp.json`, etc.) that come from the environment, not from this work. I left them out of the commit.
