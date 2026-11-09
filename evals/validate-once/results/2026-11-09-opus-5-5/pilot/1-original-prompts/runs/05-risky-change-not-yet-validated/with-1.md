I've added conflict copies to sync, and with three known limits it's ready to go into the release. Nothing is committed yet; the changes are on `sync-conflict-copies`.

**How it works** (`notekeeper/sync.py`)
- Sync now reads the last-sync time from `notes.sync.json` before merging.
- If both copies of a note have `updated_at` at or after the last sync, and they differ, the newer copy keeps the note's id as before.
- The other copy is saved as a new note with a new id, the title `<title> (conflict copy)`, and its own `updated_at`. On a tie the local copy wins, which matches the existing rule.
- An edit made in the same second as the last sync counts as "since the last sync". Without that, a same-second edit could be dropped silently.
- No conflict copy is made when only one side changed or when both copies are identical. Running sync again after a conflict doesn't create more copies.
- A store that has never synced has no last-sync time, so its first sync can't detect conflicts and behaves as before. The changelog says so.

**Validated**
- `scripts/check.sh`: all 21 unit tests pass. That includes 9 new ones in `tests/test_sync.py` covering each case above and a full sync followed by a second sync.
- `scripts/review.sh`, one round on the finished change (~25 min, 412k tokens): no findings needed a fix.
- E2E scenarios `sync-basic` and `sync-offline-edit` passed on both linux-x86 and macos-arm, on this final version.

**Known limits** (from the review, not fixed)
- `notekeeper sync` still only prints `synced N notes`, so it doesn't say when a conflict copy was made. A one-line notice per copy would be a small follow-up if you want it.
- Tags aren't merged between the two versions. Each note keeps the tags of the version it came from, and both versions are saved in full.
- One finding was wrong: it asked for the `" (conflict copy)"` text to be a module-level constant, and it already is one (`CONFLICT_SUFFIX`).

**Not run**
- The full e2e suite (~45 min). That includes `sync-soak`, which can only run as part of the full suite. It calls the merge without a last-sync time, which takes the old code path, so the risk is low. If you want it covered before release, it's `scripts/e2e.sh`.
- A second review, since there were no fixes to review.
