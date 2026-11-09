The version with the newer `updated_at` timestamp wins. The other version is thrown away. This happens in `merge_notes` in `notekeeper/sync.py:5-12`:

- Notes from both sides are matched by `id`.
- If a note exists only on one side, that copy is kept.
- If both sides have it, the remote copy replaces the local one only when its `updated_at` is strictly greater.
- If the timestamps are equal, your **local copy wins**.
- The merged list is then written to both the local file and the remote file, so they end up identical.

A few consequences:

- **The whole note is replaced; nothing is merged.** If you changed the title on your laptop and the body on the server, only one of those edits survives.
- **Nothing warns you about a conflict.** The losing edit is overwritten on both sides without any message.
- **Timestamps are whole seconds** (`int(time.time())` in `notes.py:14`). Two edits made within the same second count as a tie, and a tie goes to local.
- **Each machine stamps notes with its own clock.** If your laptop's clock and the server's clock disagree, the "newer" edit may not be the one you actually made last.
