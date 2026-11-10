I fixed the bug that was corrupting attached files. The branch is ready to merge, with two small known limits listed below. Everything is in one commit (`54ec286`) on `feat/attach-cli`. I haven't pushed or opened a PR.

**What was wrong:** `attach` read files as text and then re-encoded them as UTF-8. That doubled every byte at or above 0x80 and rewrote line endings, so any image, PDF or non-ASCII file attached from the command line was stored corrupted with no error. This is why `attach-cli-binary` failed. It now reads files in binary mode and stores them byte for byte.

**Also fixed:**
- **Leftover partial files:** if a write was interrupted, its `.tmp-*` file showed up in `files` as if it were a real attachment. Those are now hidden.
- **Folder escape:** `save_attachment` now rejects note IDs like `../x` that would write outside `attachments/`. The CLI couldn't trigger this, but since these are people's files I closed it. It also now requires the data to be bytes, so a text string can't be passed in and silently re-encoded again.
- **Size limit:** `attach` reads at most 10 MiB + 1 byte, so a huge file is rejected without loading all of it. Too-large files now get a clean error message instead of a traceback.
- **Help text:** `attach --help` now mentions the 10 MiB limit.

**How I checked it:**
- I wrote the new tests first and confirmed they failed against the old code. The binary test showed the same corruption as the report.
- All 18 unit tests pass with the fixes.
- I re-ran the `attach-cli-binary` end-to-end scenario and it passes on both linux-x86 and macos-arm.
- The other attachment code still passes bytes and note IDs are 8-character hex, so the stricter checks don't reject anything the app actually uses.

**Known limits (not fixed):**
- `files` prints nothing for a note with no attachments. Adding a "no attachments" line would be a small improvement and changes the output, so I left it for you to decide.
- Leftover `.tmp-*` files are hidden but still left on disk. Nothing cleans them up.

**Not run:** the full review round and full end-to-end suite (`validate-full.sh`, about 70 minutes and 1.5M tokens). One reviewer suggested another full round in case other CLI code reads files the same way. I searched instead: the `attach` line was the only place. My changes only touch the attachment code, and the targeted tests and scenario cover them. If you want a full run before merging anyway, `scripts/validate-full.sh` will do it.

Some untracked files in the repo root (`.bashrc`, `.idea`, `.mcp.json` and others) aren't mine. I left them alone and didn't commit them.
