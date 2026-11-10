Sync uses **last-write-wins on the whole note**, keyed by `id`. The logic is in `notekeeper/sync.py:5-12`:

```python
merged = {n["id"]: n for n in local}
for r in remote:
    mine = merged.get(r["id"])
    if mine is None or r["updated_at"] > mine["updated_at"]:
        merged[r["id"]] = r
```

- **Newer `updated_at` wins.** The remote copy replaces the local one only if its timestamp is strictly greater.
- **On a tie, your local copy wins.** The comparison uses `>`, not `>=`. `e2e/scenarios.py:65-69` tests this case.
- **The losing version is dropped.** The whole note is replaced. Sync doesn't merge fields or keep a conflict copy, so if you changed the title on one machine and the body on the other, one of those edits is lost.
- **Both sides end up with the same result.** `sync.py:18-20` writes the merged list to both the local and remote files.

Things to watch for:
- `updated_at` is stored as whole seconds (`notekeeper/notes.py:14`). Two edits made in the same second count as a tie, so the local copy wins.
- Timestamps come from each machine's own clock. If your laptop's clock is ahead of the server's, the laptop's edits can win even when the server's edit actually came later.
