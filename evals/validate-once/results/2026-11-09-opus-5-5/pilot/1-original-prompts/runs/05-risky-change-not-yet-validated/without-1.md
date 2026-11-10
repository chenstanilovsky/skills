Sync now keeps conflict copies. The unit tests and the two sync end-to-end scenarios pass. I committed it as `f088036` on `sync-conflict-copies`.

**How it works** (`notekeeper/sync.py`):
- A note counts as a conflict when both sides edited it after the last sync and the two versions are actually different.
- The newer version keeps its id and stays as is. On a tie the local copy wins, as before.
- The other version is saved as a new note with a fresh id, titled `<title> (conflict copy)`. It keeps its own body, tags and `updated_at`.
- If both sides made the same edit (same title, body and tags), no copy is made. A note edited on only one side still just takes the newer version.
- The conflict copy is written to both the local store and the remote, so running sync again doesn't make more copies.

**Decision for you:** a store with no last-sync record falls back to the old rule, where the newer version wins and nothing is copied. Without that record there's no way to tell which edits came after the last sync. It also matters for upgrades: anyone coming from 0.3.0 has no record yet, so treating every differing note as a conflict would fill their first sync with copies. The cost is that a real conflict during that first sync still loses the older version. If you'd rather keep both versions every time there's no record, it's a one-line change.

I added tests for both directions, ties, one-sided edits, identical edits, the no-record case, and a full sync round trip. I also updated `CHANGELOG.md` (under 0.4.0) and `README.md`.

**Checked:**
- `scripts/check.sh`: all 19 unit tests pass.
- `scripts/e2e.sh --scenario sync-offline-edit` and `--scenario sync-basic`: pass on both linux-x86 and macos-arm.

I didn't run the full end-to-end suite (`scripts/e2e.sh`), which includes the `sync-soak` scenario, or `scripts/validate-full.sh` (about 70 min and 1.5M tokens). Both are worth running before the release goes out; tell me if you want me to start one.
