Sync uses **last-write-wins on the whole note, based on `updated_at`**. See `notekeeper/sync.py:5-12`:

```python
merged = {n["id"]: n for n in local}
for r in remote:
    mine = merged.get(r["id"])
    if mine is None or r["updated_at"] > mine["updated_at"]:
        merged[r["id"]] = r
```

- **Newer `updated_at` wins.** Notes are matched by `id`, and whichever copy has the later timestamp is kept.
- **On a tie, your laptop's copy wins.** The remote copy replaces the local one only if its timestamp is strictly greater. `e2e/scenarios.py:65-69` tests this case.
- **The other edit is dropped completely.** Sync doesn't merge fields or the note body, and it doesn't keep a conflict copy. After merging, the result is written to both the local and remote files (`sync.py:18-20`), so the losing version is gone on both sides.

Some practical consequences:
- `updated_at` comes from each machine's own clock, in whole seconds (`notes.py:14`). If one clock is off, its edits can win or lose when they shouldn't.
- Two edits in the same second count as a tie, so the local copy wins.
- Notes that exist on only one side are kept, so sync never deletes a note.
