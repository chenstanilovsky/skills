I fixed the typo: "recieve" is now "receive" in the `sync --help` text. All 11 unit tests pass.

- **Two files changed, one line each:** the help string in `notekeeper/cli.py:24`, and the stored snapshot `tests/snapshots/sync_help.txt`, which had the same typo. Without the snapshot update, the snapshot test would have failed. The two words are the same length, so the help text wraps the same way.
- **Checks:** I ran `scripts/check.sh` (compile plus all unit tests, including the `sync --help` snapshot test). There are no other copies of "recieve" in the repo.
- **Not run:** the end-to-end suite. Its scenarios test sync behaviour, not help text, and this change is text only. It takes about 3 minutes per scenario and 45 minutes for the full suite, so it isn't worth it here.

The change isn't committed yet. Do you want me to commit it before you cut the release?
