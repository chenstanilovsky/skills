Conflict copies are added to sync and ready for the next release. There are two known limits below. The changes are in the working tree on `sync-conflict-copies` and not committed yet.

**How it works** (`notekeeper/sync.py`)
- A note is a conflict when it was edited on both sides after the last recorded sync time and the title, body or tags differ.
- The newer copy keeps the original id, as before. On a tie, the local copy wins, which matches the existing rule.
- The other copy is kept as a new note with a new id, titled `<title> (conflict copy)`. It keeps its own body, tags and `updated_at`.
- If both sides made the same edit, or only one side edited the note, no copy is made.
- **One decision for you:** a store that has never synced has no `notes.sync.json`, so there's no time to compare against. I made those stores use plain newer-wins on their first sync. Without that, anyone upgrading from 0.3.0, which didn't record sync times, would get a conflict copy for every note that differs on their first sync. If you'd rather keep both copies in that case too, it's a one-line change.
- The changelog's 0.4.0 entry and the README layout table now describe this.

**Validated** (all on the final code)
- All 19 unit tests pass, including 7 new ones: both sides edited (either side newer), a tie, only one side edited, identical edits, never synced, and a full `sync()` run that checks both files end up the same and that a second sync changes nothing.
- One review run (`scripts/review.sh`, 3 reviewers plus skeptics) found nothing that needed fixing.
- The `sync-basic` and `sync-offline-edit` end-to-end scenarios passed on linux-x86 and macos-arm.

**Known limits** (from the review, not fixed)
- `notekeeper sync` still prints only `synced N notes` and doesn't list the conflict copies it made. Printing each new copy's title and id would be a small follow-up.
- Tags aren't merged between the two versions, so each note keeps only its own. The changelog says so.
- The review also flagged the hard-coded suffix text, but it's already a single constant (`CONFLICT_SUFFIX`).

**Not run:** the full end-to-end suite (~45 min). The one test it adds is `sync-soak`, which calls the merge without a last-sync time, so its behaviour hasn't changed. I didn't think it was worth the time; I can run it if you want it before the release.
