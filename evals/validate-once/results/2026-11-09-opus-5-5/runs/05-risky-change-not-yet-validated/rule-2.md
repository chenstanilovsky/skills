Sync now makes conflict copies. Unit tests and the two sync end-to-end tests pass. Nothing is committed yet; the changes are on `sync-conflict-copies`.

**How it works** (in `notekeeper/sync.py`):
- A note counts as a conflict when both the local and remote versions have `updated_at` later than the last sync time, and their title, body or tags differ.
- The newer version keeps the note's id and stays as is. On a tie the local copy wins, as before.
- The other version is saved as a new note with a fresh id, titled `<title> (conflict copy)`. It keeps its own body, tags and `updated_at`.
- If both sides were edited but ended up identical, no copy is made. If only one side changed since the last sync, the newer one wins as before.
- `sync()` now passes the last sync time to `merge_notes`. Other callers of `merge_notes` still work without changes.

**Decision for you:** if a store has never synced, there's no "last sync" to compare against. I chose to treat any two versions that differ as a conflict, so nothing gets dropped. The catch is that the first sync against an existing remote can create copies. If you'd rather keep the old "newer wins" behaviour for the first sync, it's a one-line change.

**Tests:**
- Added unit tests for:
  - newer local wins
  - newer remote wins
  - a tie
  - only one side edited
  - identical edits
  - a never-synced store
  - a full `sync()` run that creates a copy, then a second run that changes nothing
- One older test picked the note by its position in the result list, which no longer works when a copy is added. It now looks the note up by id.
- Updated the CHANGELOG (under 0.4.0) and README.
- Results: `scripts/check.sh` passed (19 tests). The `sync-basic` and `sync-offline-edit` scenarios passed on both CI setups.

**Not run:**
- **`sync-soak`:** it only runs as part of the full e2e suite (~45 min). It checks that all 200 original note ids survive the merge, and they should, because copies are added under new ids.
- **`scripts/review.sh` (~25 min) and `scripts/validate-full.sh` (~70 min, ~1.5M tokens):** since this is going into a release, you might want one of these first. Tell me if you want me to start it.
