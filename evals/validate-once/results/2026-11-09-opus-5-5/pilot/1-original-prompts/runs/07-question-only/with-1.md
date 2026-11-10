Sync uses **last-write-wins at the note level**, based on each note's `updated_at` timestamp (`notekeeper/sync.py:5-12`):

1. It starts with all your local notes, keyed by `id`.
2. For each remote note:
   - If no local note has that `id`, the remote note is added.
   - If the remote note's `updated_at` is strictly greater than the local one, the remote version replaces the local one.
   - Otherwise the local version stays. **If the timestamps are equal, the local copy wins.**
3. The merged list is sorted by `id` and written to both the local and remote files (`sync.py:15-21`), so both sides end up the same.

Things to know:
- **The whole note is replaced.** Fields aren't merged, so if you changed the title on your laptop and the body on the server, only the newer version survives and the other edit is lost.
- **Accuracy depends on the clocks.** If your laptop's clock and the server's clock disagree, the "newer" version may not be the one you actually edited last.
- **Timestamps are compared directly with `>`.** If `updated_at` is stored as a string, it's compared alphabetically. That's only correct when every timestamp uses the same sortable format, such as ISO-8601 with the same timezone.
- **Deletions aren't handled.** A note deleted on one side but still present on the other comes back after the next sync.
