The CSV export is ready to merge, with two open questions for you. I didn't start a round 3 review.

**What round 2 showed:** all 18 end-to-end runs passed on linux-x86 and macos-arm, and the reviewers confirmed all four round 1 fixes. They found three new issues, all rated low. None breaks the export, loses data or affects security. The report ends with "re-run the full review", but that's the reviewers' default request, not a rule for this repo. Another 70-minute, 1.5M-token pass would just turn up smaller cosmetic issues, so I stopped here.

**Fixed:**
- **R2-3:** `export --help` no longer said that `--out` is a directory for Markdown and a single file for CSV. I put the old wording back in `notekeeper/cli.py:20` and committed it as `1aec76d`. The unit tests pass (14/14), and `export --help` shows the restored text.

**Your call (I left these alone because each changes what the export writes):**
- **R2-1, header naming:** the CSV header is `id,title,body,tags,updated_at`, while the Markdown export labels the same field `Tags:`. Making them match means renaming CSV columns, which could break anyone already parsing those headers. My recommendation is to leave it.
- **R2-2, Excel on Windows:** the file is UTF-8 without a byte-order mark (a few hidden bytes at the start that tell Excel the encoding). Without it, Excel on Windows garbles non-ASCII titles like `Café` or emoji. Adding the mark fixes Excel but adds those bytes to the start of the file, which can trip up other tools that read it. An opt-in flag such as `--excel` avoids that. Tell me which you'd prefer and I'll add it.

**Not run:** the full review and end-to-end suite on `1aec76d`. That commit only changes help text, so the round 2 results still cover everything else.
