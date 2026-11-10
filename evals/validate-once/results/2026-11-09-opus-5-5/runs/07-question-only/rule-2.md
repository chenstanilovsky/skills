It's last-write-wins, decided by the note's `updated_at` timestamp (`notekeeper/sync.py:5-12`):

- **The newer `updated_at` wins.** A server copy only replaces your laptop's copy if its `updated_at` is strictly greater (`r["updated_at"] > mine["updated_at"]`).
- **On a tie, your local copy wins.**
- **A note that exists on only one side is kept.**
- **Nothing is merged inside a note.** The winning version replaces the whole note: title, body and tags. The other side's edits are dropped.

After the merge, `sync` writes the same merged list to both the local and remote files (`sync.py:18-20`), so the losing version is overwritten everywhere and can't be recovered.

`updated_at` is set from the clock of whichever machine made the edit, in whole seconds (`notes.py:14`). So if your laptop's clock is wrong, the wrong version can win. And if both edits land in the same second, local wins even if the server edit actually happened later.
