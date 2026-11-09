The branch is ready to merge. The serious bug the validation found is fixed and committed, and I left six minor findings for you to decide on. I haven't pushed anything.

**The bug:** `notekeeper attach` was silently corrupting any file that wasn't plain ASCII text. It read files as text, so every byte at 0x80 or above was saved as two bytes and Windows-style line endings were changed. Images, PDFs and files with accented characters were all affected, with no error shown. It now reads files as raw bytes, so they're stored exactly as they are (`notekeeper/cli.py:54`). This is commit `376d11f` on `feat/attach-cli`.

**Checks I ran, all on the final commit:**
- I added a unit test (`test_attach_stores_bytes_unchanged`) that attaches a file containing every byte value plus CR/CRLF line endings. It failed before the fix and passes now.
- I re-ran the e2e scenario that failed overnight, `attach-cli-binary`. It now passes on both linux-x86 and macos-arm.
- All 15 unit tests pass, and the syntax check is clean.

**Other files read the same way:** One reviewer said other CLI code might have the same bug and suggested a second full review round. I searched instead: `attach` was the only place that reads a user's file. The only other file read is the app's own JSON, which is read correctly. So I didn't run the second round, which would have taken about 70 minutes and 1.5M tokens.

**Also fixed:** `attach --help` now mentions the 10 MiB limit.

**Not fixed** (none of these lose data; each is a small change if you want it):
- **Leftover temp files:** if the program is killed mid-write, a leftover `.tmp-*` file would appear in the `files` list. The real attachment is untouched. The fix is one line: hide names starting with a dot, which real attachments can't have anyway.
- **Unchecked note id:** `save_attachment` doesn't check the note id, so a note id like `../x` would write outside the attachments folder. The command line only accepts ids of notes that exist, so it can't happen from there.
- **Size checked late:** the 10 MiB limit is checked only after the whole file has been read into memory, so a very large file uses a lot of memory before it's rejected.
- **Empty `files` output:** `files` prints nothing for a note with no attachments, rather than a "no attachments" line.
- **No size-limit test:** nothing tests the 10 MiB limit directly.

**Not run:** the full e2e suite and the full review. The fix changes one line that the binary scenario and the new unit test both cover, so another full run wouldn't have tested anything new.

`git add -A` on the branch fails because of untracked dotfiles (`.bashrc`, `.claude/`, `.idea`, …) in the repo folder. I added only the two files I changed.
