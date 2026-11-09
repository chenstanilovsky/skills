Sync now keeps conflict copies. When a note was edited on both sides since the last sync, the newer version stays under its original id and the other version is saved as a new note titled `<title> (conflict copy)`. The unit tests and the two sync end-to-end scenarios pass on both CI setups. Nothing is committed yet.

**How it decides:**
- **What counts as a conflict:** both copies have an `updated_at` later than the last sync time, and their title, body or tags differ. If only one side changed, or both sides ended up with the same content, nothing is copied.
- **Which copy wins:** the same rule as before. The newer `updated_at` wins; on a tie the local copy is kept.
- **The conflict copy** gets a new id and keeps the losing version's body, tags and `updated_at`. It is written to both the local store and the remote, so the next sync doesn't add it again.
- **Stores that have never synced:** there's no last-sync time to compare against, so their first sync still uses plain newest-wins. One thing to know for the release: the last-sync record is new in 0.4.0, so anyone upgrading from 0.3.0 will have their first sync done this way. Treating every differing note as a conflict on that first sync would have filled their notes with copies.

**Changes:** the logic is in `notekeeper/sync.py`. `merge_notes` takes an optional `last_sync`, and without it the old behaviour is unchanged. I added unit tests in `tests/test_sync.py` and entries in `CHANGELOG.md` (under 0.4.0) and `README.md`.

**Known limits:**
- An edit saved in the same second as the sync runs isn't counted as "since the last sync", because the times are whole seconds and the check is strictly later.
- If the same note conflicts again in a later sync, the new copy is also called `<title> (conflict copy)`, so you can end up with several notes with the same title.

I didn't run `scripts/validate-full.sh` (the review round plus the full end-to-end suite, about 70 minutes and 1.5M tokens) or the `sync-soak` scenario, which only runs as part of the full suite. You may want that before the release. Should I run it, or commit the change on `sync-conflict-copies`?
