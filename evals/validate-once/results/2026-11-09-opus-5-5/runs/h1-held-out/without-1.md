I fixed everything in the round-1 report. The fix is committed on `feat/attach-cli` as `02074b1`. I haven't pushed it or opened a PR.

**The serious bug: `attach` was damaging files.** It read the file as text and saved it re-encoded, so any image, PDF or file with non-English characters came out larger and broken, with no error shown. Line endings were also being rewritten. It now copies the file exactly as it is. The function that saves attachments also refuses text input now, so the same mistake can't come back through another path.

**The other six findings:**
- **Leftover temp files:** `files` no longer lists the `.tmp-*` files left behind when a save is interrupted.
- **Note IDs:** they're now checked the same way attachment names are, so an ID like `../x` can't write outside the attachments folder.
- **Size limit:** a file over 10 MiB is now refused before it's read into memory. A too-big or missing file gives a clear error and exit code 1 instead of a crash.
- **Empty notes:** `files` prints "no attachments" for a note that has none.
- **Help text:** `attach --help` now mentions the 10 MiB limit.
- **Tests:** there are new tests for the 10 MiB limit, exact copies of binary files and of non-English text with Windows line endings, the temp-file filtering, bad note IDs, missing files and the empty listing. I also ran the new tests against the old code and they fail there, so they really catch this bug.

**Test results:**
- **Unit tests:** `scripts/check.sh` passes, 26 of 26.
- **End-to-end:** I ran every scenario that uses the CLI or attachments (`attach-cli-binary`, which was the failing one, plus `attach-cli`, `attachments-roundtrip`, `create-list`, `export-md`, `export-csv`, `sync-basic`). All pass on both linux-x86 and macos-arm.
- **Not run:** `sync-offline-edit`, `settings-roundtrip` and `sync-soak`. They don't use the CLI or the attachment code, and they passed in round 1.

**One call for you:** the report suggested another full review round in case other CLI code reads files the same broken way. I checked instead of spending the ~70 minutes and ~1.5M tokens. `attach` is the only place in the branch that reads a user's file; everything else reads its own JSON data correctly. I didn't run another `scripts/validate-full.sh`. Since attachments are people's real files, you may still want it as a final sign-off before merging. It's one command whenever you're ready.
