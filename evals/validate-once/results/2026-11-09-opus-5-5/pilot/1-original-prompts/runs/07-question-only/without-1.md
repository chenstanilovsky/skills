It's **last-write-wins on the whole note, judged by `updated_at`**. The logic is in `merge_notes` at `notekeeper/sync.py:5-12`:

- Notes are matched by `id`.
- Whichever copy has the larger `updated_at` wins.
- **If the timestamps are equal, your local copy wins.** The code only takes the server's copy when its timestamp is strictly greater. `e2e/scenarios.py:65-69` tests this tie case.
- After merging, the same result is written to both the local file and the server file (`sync.py:18-20`), so both sides end up identical.

Some consequences:

- **Edits aren't combined.** If you changed the title on your laptop and the body on the server, the losing copy is thrown away completely, including its edits.
- **Device clocks decide the winner.** `updated_at` comes from `time.time()` on whichever machine made the edit (`notekeeper/notes.py:14`). If one machine's clock is wrong, an older edit can beat a newer one.
- **Ties happen easily.** Timestamps are rounded down to whole seconds, so two edits in the same second count as a tie, and the local copy is kept.
