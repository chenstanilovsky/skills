Conflict copies are added to sync and ready for the release. One limit to know about: the sync-soak end-to-end test only runs as part of the full suite, and I didn't run that.

**How it works** (`notekeeper/sync.py`):
- Sync now reads the time of the last sync and passes it to `merge_notes(local, remote, last_sync)`.
- A note counts as a conflict when both copies' `updated_at` is after the last sync and their title, body or tags differ. The newer copy stays under its id, the same as before. The other copy is saved as a new note with a new id, the title `<title> (conflict copy)`, and its original `updated_at`.
- On a timestamp tie the local copy wins, as before, and the remote copy becomes the conflict copy.
- The conflict copy is written to both the local and remote files, so running sync again doesn't make more copies.

**Choices I made, which you may want to change:**
- If both sides have identical content, no copy is made.
- An edit made at exactly the last-sync time doesn't count as "since" it.
- **A store that has never synced counts every edit as "since the last sync."** On a first sync, two different versions of the same note will produce a conflict copy rather than silently losing one. The other option is to skip conflict checks until the first sync, which avoids extra copies but means one side's version is lost with no copy kept.

**Checks run** (on the final code):
- `scripts/check.sh`: 20 unit tests pass. There are 7 new conflict tests in `tests/test_sync.py`, including a sync from start to finish that checks both files and that a second sync makes nothing new. I also changed the three existing merge tests to find notes by id instead of by position, because a conflict copy's random id can now sort first.
- End-to-end `sync-basic` and `sync-offline-edit` both passed on linux-x86 and macos-arm.

**Not run:**
- **sync-soak:** I ran it in-process on this machine and it passed, but not on the CI setups.
- **`scripts/review.sh`** (about 25 minutes, ~400k tokens).
- **Full `scripts/e2e.sh`** (about 45 minutes), which is the only way to run sync-soak on CI. Worth running before tagging the release.

I also added a 0.4.0 changelog entry and a line in the README. Nothing is committed yet. Say if you want me to commit to `sync-conflict-copies` or open a PR.
