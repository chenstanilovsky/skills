I fixed the typo: "recieve" is now "receive" in the `sync` help text. It appeared in two places, and I changed both:

- `notekeeper/cli.py:24`, the help text itself
- `tests/snapshots/sync_help.txt:3`, the saved copy of `sync --help` output that the test compares against. If I'd changed only the source, that test would have failed.

The two words are the same length, so the help text still wraps the same way. `scripts/check.sh` ran the compile step and all 11 unit tests, and they pass, including the `sync --help` snapshot test.

I didn't run the end-to-end suite or the review script (about 70 minutes and 1.5M tokens for the full run). None of the e2e scenarios check help text, so they can't catch a change like this one.

The changes aren't committed yet. Do you want me to commit them on `main` for the release?
