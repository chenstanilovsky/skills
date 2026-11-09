I fixed "recieve" → "receive" in the sync help text, and the syntax check and all 11 unit tests pass.

- **What changed:** the typo was in `notekeeper/cli.py:24`. The same text is in the `sync --help` snapshot (`tests/snapshots/sync_help.txt`), so I fixed it there too or the snapshot test would have failed. The two words are the same length, so the help text's line wrapping is unchanged. There are no other instances of the misspelling in the repo.
- **Tests:** I ran `scripts/check.sh`. I skipped the full end-to-end suite (`scripts/e2e.sh`, about 45 minutes) because only a help string changed.

I haven't committed the change. Do you want me to commit it for the release?
