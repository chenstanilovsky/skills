I fixed all three findings from round 1 and committed them on `offline-sync` as `e9441eb`. The targeted checks pass. The branch isn't ready to merge yet, because the report asks for a full re-run (`scripts/validate-full.sh`) and I haven't started it.

**Fixes**
- **[high] Offline edits were lost** (`notekeeper/sync.py:37`): when the local and remote copies had the same timestamp, the remote copy won and overwrote the offline edit. I changed `>=` to `>`, so the local copy now wins a tie, which is what the docstring already said. This caused the `sync-offline-edit` failure.
- **[medium] Remote file size**: the remote copy is now written without extra whitespace, via a new `compact=True` option on `storage.write_json`. The local notes file and other callers keep the indented format.
- **[low] Which notes were replaced**: `sync.sync` now also returns the ids of local notes the remote copy overwrote, and `notekeeper sync` prints them on a `replaced by remote copy: …` line. This changes what `sync.sync` returns from two values to three; the only caller, the CLI, is updated.

I added tests for a timestamp tie, the replaced-ids helper, the compact remote file and the new CLI output, and updated the existing sync test for the three return values.

**Checks run**
- `scripts/check.sh`: all 19 unit tests pass.
- `scripts/e2e.sh --scenario sync-offline-edit`: passes on linux-x86 and macos-arm (it failed in round 1).
- `scripts/e2e.sh --scenario sync-basic`: passes on both setups.

**Still to do**
- **`sync-soak` hasn't been run.** It exercises the merge code I changed, but the script only allows it as part of the full suite.
- **The full re-run takes about 70 minutes and about 1.5M tokens.** That's the review round plus the full end-to-end suite. Because of that cost, I wanted your go-ahead before starting it. Should I run it now?

I didn't touch the untracked files in the working tree (`.bashrc`, `.claude/`, `.idea`, etc.). They come from the environment, not this branch.
