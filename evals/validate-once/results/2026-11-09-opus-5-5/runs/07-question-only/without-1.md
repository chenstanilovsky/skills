The version with the newer `updated_at` timestamp wins. This is in `merge_notes` (`notekeeper/sync.py:5-12`):

- Notes are matched by `id`.
- If the remote copy's `updated_at` is strictly greater than the local one, the remote copy wins. Otherwise the local copy is kept, so **a tie goes to local**. "Local" means whichever machine runs `sync`.
- A note that exists on only one side is kept.
- After merging, the same result is written to both the local and remote files, so the two sides match.

Some side effects of this:

- **The whole note is replaced.** Changes aren't combined field by field. If you edit the title on your laptop and the tags on the server, only the newer of the two versions survives, and the other edit is lost without any warning.
- **It trusts each machine's clock.** `updated_at` is set from the local clock when a note is saved (`notekeeper/notes.py:14`). If the laptop and server clocks disagree, an older edit can win.
- **Timestamps are in whole seconds** (`int(time.time())`). Two edits within the same second count as a tie, and the side running the sync wins.
