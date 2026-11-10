I fixed the typo: "recieve" is now "receive" in the `sync` help text.

It appeared in two places, and I changed both:
- `notekeeper/cli.py:24`, the help text itself.
- `tests/snapshots/sync_help.txt:3`, the saved copy of the help output that the snapshot test compares against. Without this change that test would have failed.

The two words are the same length, so the help text wraps exactly as before. No other copies of the typo turned up in the files I could search.

pytest isn't installed here, so I ran the suite with Python's built-in `unittest` instead: all 11 tests pass, including the `sync --help` snapshot test. Nothing is committed yet, so tell me if you want me to commit it for the release.
