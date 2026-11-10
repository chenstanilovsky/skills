I fixed the typo: the `sync` help text now says "receive" instead of "recieve". All 11 tests pass under the project's `scripts/check.sh`.

- **Code:** fixed in `notekeeper/cli.py:24`.
- **Snapshot:** `tests/snapshots/sync_help.txt` had the old spelling too, so I updated it to match. Without that, the `sync --help` snapshot test would have failed. Both words are the same length, so the help text still wraps the same way.

I didn't run the end-to-end suite (`scripts/e2e.sh`) because only help text changed and the snapshot test checks that output exactly. Nothing is committed yet; tell me if you want it committed for the release.
