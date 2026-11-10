Sync uses **last-write-wins on the whole note**, in `notekeeper/sync.py:5-12` (`merge_notes`):

- Notes are matched by `id`.
- The copy with the larger `updated_at` wins, and it replaces the other copy completely. Fields from the two versions are never combined.
- **If the timestamps are equal, your laptop's copy is kept.** The remote copy only replaces it when its `updated_at` is strictly greater.
- A note that exists on only one side is kept.

After merging, the same result is written to both the local and remote files (`sync.py:18-20`), so the losing edit is overwritten on both sides and no conflict copy is saved.

Some side effects of this design:
- `updated_at` is an integer Unix timestamp in seconds, set from the device's own clock (`notes.py:14`). If the laptop and server clocks disagree, the wrong version can win. Two edits made in the same second count as a tie, so the laptop wins.
- If you change the title on one machine and the body on the other, one of those changes is lost.

The tests confirm this: `tests/test_sync.py` covers newer-wins in both directions, and `e2e/scenarios.py:65-69` checks that the local copy is kept on a tie.
