I fixed the typo: "recieve" is now "receive". It appeared in two places, and both needed the change:

- `notekeeper/cli.py:24`, the `sync` description text
- `tests/snapshots/sync_help.txt:3`, the saved copy of `sync --help` output that the snapshot test compares against

The two spellings are the same length, so the help text still wraps the same way. `scripts/check.sh` (syntax check plus all 11 unit tests, including the `sync --help` snapshot test) passes.

I didn't run the end-to-end suite in `scripts/e2e.sh`. The full run takes about 45 minutes, and a change to one help string won't affect sync, export or storage. If your release process requires a full e2e run anyway, that's the one thing left to do.

The changes aren't committed yet. Tell me if you want me to commit them.
