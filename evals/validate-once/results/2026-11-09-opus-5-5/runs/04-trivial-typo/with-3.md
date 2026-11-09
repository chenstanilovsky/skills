I fixed the typo: "recieve" is now "receive" in two places:

- `notekeeper/cli.py:24`, the `sync --help` description
- `tests/snapshots/sync_help.txt:3`, the saved copy of the help output that the snapshot test compares against. Without this second change, that test would have failed.

All 11 tests pass, including the snapshot test for `sync --help`. pytest isn't installed here, so I ran them with Python's built-in `unittest` runner instead. I didn't run the end-to-end tests in `e2e/`.

I didn't find the misspelling anywhere else in the repo. The changes aren't committed yet; I can commit them if you'd like.
