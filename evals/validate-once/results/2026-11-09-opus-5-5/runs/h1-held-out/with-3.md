The branch is ready to merge. The high-severity corruption bug is fixed and the e2e scenario that caught it now passes on both platforms. A few low-severity findings are left as known limits, listed below. The fix is commit `3e3291d` on `feat/attach-cli`. I haven't pushed it or opened a PR.

**The bug:** `attach` read the file as text and then saved it re-encoded as UTF-8. Any byte at or above 0x80 was stored as two bytes, and line endings were rewritten. Every image, PDF or non-ASCII file attached from the command line was silently corrupted. It now reads the file in binary mode. `save_attachment` also rejects text input with an error, so a caller can't reintroduce the bug unnoticed.

**Validated (on the final commit):**
- Unit tests: 18/18 pass. Three new tests failed before the fix and pass now.
- E2E: `attach-cli-binary` (the scenario that failed), `attach-cli` and `attachments-roundtrip` pass on linux-x86 and macos-arm, 6/6.

**Fixed:**
- **[high] Corrupted attachments.** Covered by the new byte-exact unit test (the file includes CR/CRLF and all 256 byte values), the type-check test, and the `attach-cli-binary` scenario.
- **[medium] `files` listed leftover `.tmp-*` files.** A half-written file from a killed process would have shown up as a real attachment, so I treated this as a data-integrity issue. `list_attachments` now skips dot-files, which `save_attachment` already refuses as names. A new test covers it.
- **[low] Whole file read before the size check.** I was rewriting that read anyway, so it now stops one byte past 10 MiB and rejects the file without loading all of it.
- **[low] No test for the 10 MiB limit.** Added one; it checks the oversized file is rejected and nothing is stored.
- **[low] `attach --help` didn't mention the limit.** Text added.

**Known limits (not fixed):**
- `save_attachment` doesn't validate `note_id`. A value like `../x` would write outside `attachments/`, but the CLI only accepts ids that exist, so a user can't trigger it.
- `files` prints nothing for a note with no attachments, rather than a "no attachments" line. This is cosmetic.

**Not run:** a second full review round. A reviewer suggested one because other CLI code might read files the same way. I checked directly instead: the `attach` line was the only `open()` in the CLI. The rest of the package reads files through the JSON reader in `storage.py`, which is correct for its text data. I also didn't re-run the full 71-minute validation (1.5M tokens). The fix only touches the attach path, and the scenarios above cover it. If you want the full run anyway before merging, it's `scripts/validate-full.sh`.

The working directory has some untracked dotfiles (`.bashrc`, `.gitconfig`, `.claude/` and similar). They look like environment leftovers, so I left them out of the commit.
