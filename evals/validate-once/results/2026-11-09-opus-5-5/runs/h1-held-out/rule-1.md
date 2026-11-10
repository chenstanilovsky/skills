I fixed the high and medium findings, plus two of the low ones that affect safety and memory use. Everything is committed on `feat/attach-cli` as `edd067f`. I haven't pushed or merged.

**What was fixed**
- **[high] Corrupted attachments:** `notekeeper attach` read files as text, so every image, PDF or non-ASCII file was stored damaged with no error. It now reads files as raw bytes and stores them unchanged. As a backstop, `save_attachment` now refuses text data outright, so the same mistake can't quietly happen again.
- **[medium] Leftover temp files:** if a save is killed partway through, it can leave a hidden temp file behind. `files` no longer lists those as attachments.
- **[low] Note id not checked:** `save_attachment` and `list_attachments` now reject note ids that could write outside the attachments folder (`..`, `a/b`, empty, hidden names). The CLI couldn't reach this, but it's cheap protection for people's files.
- **[low] Big files read before rejection:** the 10 MiB limit is now checked against the file's size before anything is read. Files that are too large, and files that are missing or unreadable, now fail with a clear message and exit code 1 instead of a crash.

**Tests**
- I added unit tests for the 10 MiB limit (which closes another low finding), byte-exact binary and CRLF storage through the CLI, rejection of text data, bad note ids, hidden temp files, and missing files. When I put back the old CLI code, the new test fails, so it catches the original bug.
- `scripts/check.sh`: all 21 unit tests pass.
- I re-ran the three attachment end-to-end scenarios on both setups (`attach-cli-binary`, `attach-cli` and `attachments-roundtrip`), and all passed. `attach-cli-binary` was the one that failed in the nightly run.

**What I didn't run**
- **The full 70-minute, 1.5M-token validation again.** The skeptic suggested another full review because other file-reading code might have the same bug. I searched instead: that one line was the only text-mode file read in the package. The other seven e2e scenarios don't touch the changed code and passed in round 1. If you want a full re-run before merging anyway, it's `scripts/validate-full.sh`.

**Left as is (polish, from the low findings)**
- `files` prints nothing for a note with no attachments, instead of a "no attachments" line.
- `attach --help` doesn't mention the 10 MiB limit.

Each is a one-line change if you want them before merging.
