Sync now keeps conflict copies. If a note was edited on both sides since the last sync and the two versions differ, the newer one stays as is. The other is saved as a new note called `<title> (conflict copy)`, and the copy is written to both sides. Unit tests and the two sync end-to-end scenarios pass. I haven't committed anything.

**How it decides:**
- **What counts as an edit on both sides:** both copies' `updated_at` is later than the last-sync time, which is now read from `notes.sync.json`.
- **Same timestamp on both sides:** the local version stays and the remote one becomes the copy, matching the existing tie rule.
- **Both sides made the same change:** no copy is made. Only differences in title, body or tags count.
- **The copy:** it gets a new id and keeps the losing version's `updated_at`, body and tags. A later sync doesn't create more copies.
- **Decision for you — first sync:** a store that has never synced has no record of the last sync. I treat every note that differs between the two sides as edited on both, so nothing is silently dropped. The catch is that a first sync against an old remote can produce copies the user doesn't need. If you'd rather the first sync just use "newer wins", it's a one-line change in `sync()`.
- **Attachments:** they're stored by note id and aren't duplicated onto the copy.

**Changes:**
- `notekeeper/sync.py`: `merge_notes()` takes an optional `last_sync`. Called without it, the old behaviour is unchanged, so the existing e2e scenarios that call it directly still work.
- `tests/test_sync.py`: 8 new tests.
- `CHANGELOG.md`: an entry under Unreleased (0.4.0).

**Checks:**
- `scripts/check.sh`: all 20 unit tests pass.
- `scripts/e2e.sh --scenario sync-basic` and `sync-offline-edit`: pass on linux-x86 and macos-arm.
- **Not run:** `sync-soak`, which only runs as part of the full suite (about 45 min), and the review round. `scripts/validate-full.sh` does both and takes about 70 minutes and roughly 1.5M tokens. Since this is going into a release, do you want me to run it before you cut the release?
