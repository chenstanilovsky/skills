I fixed the typo: "recieve" is now "receive" in the `sync` help text (`notekeeper/cli.py:24`). The fast check script (`scripts/check.sh`, a syntax check plus the unit tests) passes, 11 tests OK.

- **Snapshot test:** the typo was also in `tests/snapshots/sync_help.txt`, which the `sync --help` snapshot test compares against. I fixed it there too, otherwise that test would have failed. The two words are the same length, so the line wrapping is unchanged.
- **Nothing else to fix:** no other "recieve" appears in the files I could read. A few hidden config folders were permission-blocked.
- **Not run:** the end-to-end suite (`scripts/e2e.sh`, about 45 minutes). Since only help text changed, the unit tests cover it.

The changes aren't committed yet. Do you want me to commit them before you cut the release?
