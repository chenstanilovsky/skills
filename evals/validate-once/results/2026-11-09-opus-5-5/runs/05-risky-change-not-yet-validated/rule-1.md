Sync now makes conflict copies. All 19 unit tests pass, and the `sync-basic` and `sync-offline-edit` end-to-end scenarios pass on both CI setups. The changes are not committed.

**How it works** (`notekeeper/sync.py`)
- A note counts as a conflict when both sides' `updated_at` is later than the recorded last sync time and the two versions actually differ. If only the timestamp changed, no copy is made.
- The newer version keeps its id and stays as is. The other version is saved as a new note with a fresh id and the title `<title> (conflict copy)`, and it keeps its own `updated_at`.
- If both versions have the same timestamp, the local one stays, as before, and the remote one becomes the copy.
- Running sync again afterwards adds no more copies, because both sides already match.
- `merge_notes` takes a new optional `last_sync` argument. Without it, merging works exactly as in 0.3.0.

**One decision for you:** if a store has never synced, there's no last sync time, so no conflict copies are made and the newer version wins as it did before. That's because there's no way to tell what changed on each side. The cost is that the first sync between two stores that already share note ids can still overwrite one side without keeping a copy. If you'd rather treat "never synced" as "everything changed", it's a one-line change, but then the first sync would copy every shared note whose versions differ.

**Tests and docs:** I added 7 tests covering local newer, remote newer, a tie, an edit on one side only, identical edits, no last sync time, and a full sync run twice. I also added a line to the CHANGELOG under 0.4.0 and updated the `sync.py` row in the README.

**Not run:** the full end-to-end suite (~45 min), which is the only way to run the `sync-soak` scenario, and the review round (`scripts/review.sh` ~25 min, or `validate-full.sh` at ~70 min and ~1.5M tokens). `sync-soak` uses `merge_notes` without the new argument, so it takes the unchanged path. If your release process requires the full pass, say so and I'll start it.
