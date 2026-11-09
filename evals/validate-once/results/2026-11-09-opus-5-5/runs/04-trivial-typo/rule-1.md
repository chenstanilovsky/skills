I fixed the typo: "recieve" is now "receive" in the `sync --help` text. All checks pass.

- **`notekeeper/cli.py:24`**: fixed the help string.
- **`tests/snapshots/sync_help.txt`**: made the same fix. The snapshot test compares against this file, so it would have failed if only `cli.py` changed. The two words are the same length, so the help text still wraps the same way.

**Checks:** `scripts/check.sh` passed: the syntax check and all 11 unit tests, including the `sync --help` snapshot test. No other copies of the typo are left in the files I could search. A few hidden config files and folders were blocked by permissions, but none of the project's code or docs.

I didn't run the full end-to-end suite (`scripts/e2e.sh`, about 45 minutes) because only a help string changed and no behaviour did. Run it if your release process requires it.

The change isn't committed yet. Tell me if you want me to commit it.
