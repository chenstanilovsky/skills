I fixed all 7 findings from the validation report and committed them to `feat/attach-cli` as `04e39a0`. Unit tests pass, and the three attachment e2e scenarios pass on both linux-x86 and macos-arm. I haven't pushed or opened a PR.

**The serious bug (high):** `attach` was corrupting any file that wasn't plain ASCII text. Images, PDFs and non-ASCII files came out bigger and unreadable, and CRLF line endings got rewritten. It reported no error. It now reads the file as raw bytes, so the stored copy matches the original exactly. `save_attachment` also refuses text input now, so this can't quietly come back. The `attach-cli-binary` scenario that failed overnight now passes.

**The other findings:**
- **Leftover temp files (medium):** a write that gets killed partway can leave a `.tmp-*` file behind. `files` no longer lists these.
- **Note IDs (low):** `save_attachment` and `list_attachments` now reject IDs like `../x`, so nothing can be written outside the attachments folder even when called from other code.
- **Large files (low):** the 10 MiB limit is now checked while reading, so a multi-GB file is rejected after about 10 MiB instead of being loaded into memory first.
- **Error handling:** a missing or too-large file now gives a clean error and exit code 1 instead of a crash.
- **Smaller items (low):** `attach --help` now mentions the 10 MiB limit, and `files` prints "no attachments for note …" when there are none. That message goes to stderr so scripts that read the file list aren't affected. I added unit tests for the size limit, binary files, bad IDs, temp-file filtering and the error cases (24 tests in total, all passing).

**Checks I chose not to run:**
- **Second full review round:** the reviewer suggested one in case other CLI code reads files the same way. I searched instead: the attach command was the only place reading files that way. So I didn't spend the ~25 minutes and ~400k tokens.
- **Full e2e suite (~45 min):** I ran only the scenarios that cover the changed code. The other scenarios (sync, export, settings) don't use the attachment code or the shared storage helper, which I didn't change. If you want full nightly-level confidence before merging, `scripts/validate-full.sh` is the command (about 70 min).

There are untracked files in the repo folder that aren't mine (`.bashrc`, `.zshrc`, `.mcp.json`, `.claude/`, `.idea`, `.vscode` and others). I left them alone and didn't commit them, but you may want to tidy them up or add them to `.gitignore` before merging.
