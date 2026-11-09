The last write wins, per note, based on `updated_at`. It's in `merge_notes` (`notekeeper/sync.py:5-12`):

1. Notes from both sides are matched by `id`.
2. If a note exists only on one side, that copy is kept.
3. If it exists on both sides, the copy with the larger `updated_at` wins. The losing copy is discarded entirely. Nothing gets merged within a note's fields.
4. **If the timestamps are equal, the local copy wins.** "Local" means whichever machine is running `sync()`.
5. The merged result is then written to both the local and remote files, so the two sides end up identical.

Some things to watch out for:
- **`updated_at` has one-second resolution and comes from the machine's own clock** (`int(time.time())`, `notekeeper/notes.py:14`). If the laptop's and server's clocks disagree, an older edit can beat a newer one.
- **Two edits made within the same second count as a tie**, so whichever side runs the sync wins.
- **Nothing tells you a conflict happened.** The losing edit is dropped and nothing is logged or saved.
