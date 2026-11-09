Sync now keeps conflict copies. It's committed as `9178fdc` on `sync-conflict-copies`. I haven't run the full validation yet, and I'd suggest running it before this goes into the release (see the end).

**How it works** (`notekeeper/sync.py`):
- A note counts as a conflict when its local and remote copies differ and both have `updated_at` later than the recorded last sync.
- The newer copy keeps the original id and stays as is. On a tie the local copy wins, same as before.
- The other copy is saved as a new note titled `<title> (conflict copy)`. It keeps its own body, tags and `updated_at`, and the result is written to both sides.
- The copy's id comes from its content, not a random value. So if a sync is interrupted and run again, you get the same copy rather than a duplicate.
- Copies that are identical apart from the timestamp are not treated as a conflict, and neither are notes edited on only one side.

**Decision for you:** if a store has never synced, there is no "since", so any note whose two copies differ gets a conflict copy. I chose that because it never loses an edit. The downside is that the first sync between two stores that already differ could create a lot of copies. If you'd rather the newer copy just win on a first sync, that's a one-line change.

**Tests:**
- `scripts/check.sh` passes: 20 unit tests, including 8 new ones covering who wins, ties, edits on one side only, identical edits, never-synced stores, a re-run producing no duplicate, and a full `sync()` run on both sides.
- I had to change two existing tests, which used to read the first note in the merged list. A conflict copy can now sort first, so they look the note up by id instead.
- The `sync-basic` and `sync-offline-edit` e2e scenarios passed on both CI setups.
- `sync-soak` can only run inside the full e2e suite. I called its function directly and it passed, but that wasn't on the CI setups.

**Not run:** the full e2e suite (about 45 min) and the review round (`scripts/review.sh`, about 25 min and 400k tokens), or both together with `scripts/validate-full.sh` (about 70 min, 1.5M tokens). I didn't start them without asking given the cost. The change touches the merge logic that `sync-soak` stresses, so I'd recommend running `scripts/validate-full.sh` before release. Do you want me to start it?

I also updated `CHANGELOG.md` (under 0.4.0) and the sync line in the README.
