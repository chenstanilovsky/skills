It's last-write-wins, decided per note by its `updated_at` timestamp. The logic is in `notekeeper/sync.py:5-12`:

```python
merged = {n["id"]: n for n in local}
for r in remote:
    mine = merged.get(r["id"])
    if mine is None or r["updated_at"] > mine["updated_at"]:
        merged[r["id"]] = r
```

- **The newer `updated_at` wins.** The server copy only replaces your laptop's copy if its timestamp is strictly greater.
- **On a tie, the laptop's copy wins.** Because the comparison is `>`, an equal timestamp keeps the local version.
- **The whole note is replaced.** Fields aren't merged. If you changed the title on one machine and the body on the other, only one of those edits survives. The other is dropped without any warning.
- **Ties happen more often than you'd expect.** `updated_at` is stored as whole seconds (`int(time.time())` in `notekeeper/notes.py:14`), so two edits made in the same second count as a tie. The result also depends on each machine's clock, so if a clock is off, an older edit can win.
- **Both sides end up the same.** After merging, `sync` writes the result to both the local and remote files (`sync.py:18-20`).

The tests in `tests/test_sync.py` and `e2e/scenarios.py:65-69` cover this behavior, including the tie case where local wins.
