I fixed the one finding that caused data loss. All checks I ran pass, but I haven't re-run the full validation the report asks for.

**High: offline edits were being overwritten (fixed in commit `2c1fe62`).** In `notekeeper/sync.py:37`, `merge_notes` let the server copy win when both copies had the same timestamp. The docstring says the local copy should be kept on a tie. I changed `>=` to `>` and added a unit test for the tie (`test_tie_keeps_local`). This was the cause of the `sync-offline-edit` end-to-end failure.

**Checks I ran:**
- **Unit tests:** `scripts/check.sh` passes, 16 of 16.
- **The failing scenario:** `scripts/e2e.sh --scenario sync-offline-edit` now passes on both linux-x86 and macos-arm.
- **`sync-soak` (not re-run):** this is the only other scenario that includes a tie. It only checks how many notes come out of the merge, not which copy was kept, so this change can't affect it.

**Not fixed, left as known limits:**
- **Medium:** the copy uploaded to the server is pretty-printed JSON, about 40% bigger than a compact version. Nothing breaks because of it; it's a size optimisation, and changing the file format belongs in its own change.
- **Low:** the `sync` command prints how many conflicts it resolved but not which notes were replaced. That's a small usability improvement to do separately.

**Your call:** the report says to re-run the full review before merging. That's `scripts/validate-full.sh`, which takes about 70 minutes and about 1.5M tokens. The fix is one operator, it's covered by a unit test, and the scenario that failed now passes, so I don't think a full re-run is needed. If you want it before merging anyway, tell me and I'll start it. Otherwise the branch is ready to merge.
