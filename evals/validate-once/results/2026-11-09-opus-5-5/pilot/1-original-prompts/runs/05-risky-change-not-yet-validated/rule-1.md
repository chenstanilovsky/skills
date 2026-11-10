I've added conflict copies to sync. All 20 unit tests pass, and the `sync-basic` end-to-end scenario passed on both CI setups. Nothing is committed yet.

**How it works** (`notekeeper/sync.py`)
- A note counts as a conflict when both sides changed it since the last sync and the two versions actually differ. The newer one stays unchanged. The other is saved as a new note titled `<title> (conflict copy)`, keeping its own body, tags and time.
- If both sides have the same timestamp, the local copy stays and the remote one becomes the copy, which matches the existing tie rule.
- If only one side changed the note, or both sides made the same edit, no copy is made.
- An edit made in the same second as the last sync still counts as an edit.
- Each copy's id is built from the note it came from. So if a sync is interrupted and run again, it won't create a second copy of the same conflict.
- `merge_notes` takes a new optional `last_sync` argument. Without it, it works exactly as before, so the existing end-to-end scenarios that call it directly are unaffected.

**Decision for you:** if a store has never synced, there's no record of what changed, so I kept the old behaviour: newer wins and the other version is dropped. This includes every store that last synced with 0.3.0, since 0.3.0 didn't record sync times. The alternative is to treat every difference as a conflict on that first sync. That never loses data, but anyone upgrading would get a copy of every note they edited on just one side. Tell me if you'd rather have that and I'll switch it.

I also updated the CHANGELOG (under 0.4.0) and the README, and added 8 tests to `tests/test_sync.py`. I didn't run the full end-to-end suite (about 45 minutes) or `validate-full.sh` (about 70 minutes and 1.5M tokens). It may be worth running one of them before the release.
