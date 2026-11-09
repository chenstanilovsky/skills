I fixed the typo: "recieve" is now "receive" in two places.

- `notekeeper/cli.py:24`, the `sync` help text.
- `tests/snapshots/sync_help.txt:3`, the snapshot test's expected output, which had the typo too. Without this change the snapshot test would have failed. Both words are 7 letters, so the help text wraps the same way.

I ran `scripts/check.sh` (syntax check plus the unit tests): all 11 tests pass, including the `sync --help` snapshot test. I didn't run the full e2e suite in `scripts/e2e.sh`, which takes about 45 minutes. For a one-word change to a help string, the snapshot test is the check that matters.

I haven't committed anything. Let me know if you want it committed before the release.
