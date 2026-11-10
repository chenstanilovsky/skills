Sync uses **last-writer-wins at the note level**. The logic is in `notekeeper/sync.py:5-12` (`merge_notes`):

- Notes are matched by `id`.
- The copy with the **larger `updated_at`** wins, and the whole note is replaced. Title, body and tags are not merged field by field, so the losing side's edits are dropped.
- **On a tie, the local copy (the laptop's) is kept**, because the remote copy only replaces it when its timestamp is strictly greater (`>`).
- Notes that exist on only one side are kept.
- After merging, the same merged list is written to both the local and the remote files (`sync.py:18-20`), so both sides end up identical.

Keep in mind that `updated_at` comes from the clock of the device that made the edit (`time.time()` in `notekeeper/notes.py:14`), in whole seconds. If your laptop's clock and the server's clock disagree, an older edit can win. Two edits made in the same second count as a tie, so the local one wins.

The tests in `tests/test_sync.py` and `e2e/scenarios.py:65-69` check this behavior, including the rule that local wins on a tie.
