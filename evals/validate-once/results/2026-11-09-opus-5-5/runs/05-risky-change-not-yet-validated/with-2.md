Conflict copies are working and ready for the 0.4.0 release, with two known limits listed below. I haven't committed anything.

**How it works**
- A note counts as a conflict when both sides changed it after the last sync and the two versions differ. "Changed" means its `updated_at` is later than the last-sync time.
- The newer version stays as is, and the tie rule is unchanged (local wins on a tie). The other version is saved as a new note with a new id, titled `<title> (conflict copy)`. The copy goes to both the local and remote files.
- If both sides made the same edit, or only one side changed the note, no copy is made.
- **No copies on a store's first sync.** With no last-sync time there's no way to tell an edit made on both sides from one made on a single side. Copying there would hit everyone upgrading from 0.3.0 with a pile of unneeded copies. If you'd rather make copies on a first sync too, tell me.
- The change is in `notekeeper/sync.py`. `merge_notes` takes a new optional `last_sync` argument, so existing callers behave as before. I also added 7 tests in `tests/test_sync.py`, and updated `CHANGELOG.md` and `README.md`.

**Checks:** I treated this as a risky change because sync writes stored data, so it got one review round:
- All unit tests pass (19 in total).
- One run of `scripts/review.sh` (3 reviewers plus skeptics).
- The e2e scenarios `sync-basic` and `sync-offline-edit`, run on the final version, passed on both linux-x86 and macos-arm.

**Review findings:**
- One finding was wrong: it said the suffix was hard-coded, but it's already a constant, `sync.CONFLICT_SUFFIX`.
- One finding (tags aren't merged) is how "keep both" is meant to work, so I added a changelog line saying so.

**Known limits:**
- `notekeeper sync` still prints only `synced N notes`. It doesn't list which notes got conflict copies, so a user might not notice them. That's a small change to `cli.py` if you want it in this release.
- Each copy keeps its own version's tags; tags aren't combined across the two notes.

**Not run:** the full e2e suite (~45 min) and `validate-full.sh` (~70 min, ~1.5M tokens). The only remaining scenario that uses sync is `sync-soak`. It never passes a last-sync time, so it still takes the old code path. I can run the full suite if you want it before release.
