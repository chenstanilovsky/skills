I fixed the typo: "recieve" is now "receive" in the `sync` help text. Nothing's broken; the project's check script (`scripts/check.sh`) passes, with all 11 unit tests OK.

- **Changed:** the help string at `notekeeper/cli.py:24`.
- **Also changed:** the saved expected output in `tests/snapshots/sync_help.txt`, which is how the test for `sync --help` checks the text. Without this update, that test would have failed.

Only the text changed, and the help-text test covers exactly that, so I didn't run the end-to-end tests (`scripts/e2e.sh`) or the full validation script. The typo appeared nowhere else, including the README and changelog.

I haven't committed anything. Should I commit the fix to `main` before you cut the release?
