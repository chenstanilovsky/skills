#!/bin/bash
set -e
. "$(dirname "$0")/../_shared/notekeeper.sh"
nk_base
nk_git branch -M main

# Plain repo: no pending change and no earlier validation reports. The user only asks how sync
# resolves a note edited on two devices (answer: notekeeper/sync.py merge_notes).

# Line numbers for the review service's findings (used only if a review round is run).
L_MERGE=$(grep -n '^def merge_notes' notekeeper/sync.py | cut -d: -f1)
L_CMP=$(grep -n 'r\["updated_at"\] > mine\["updated_at"\]' notekeeper/sync.py | cut -d: -f1)
L_SORT=$(grep -n 'return sorted(merged.values()' notekeeper/sync.py | cut -d: -f1)
L_WLOCAL=$(grep -n 'storage.write_json(local_path, merged)' notekeeper/sync.py | cut -d: -f1)
L_RET=$(grep -n '    return merged$' notekeeper/sync.py | cut -d: -f1)
L_NOW=$(grep -n '"updated_at": int(' notekeeper/notes.py | cut -d: -f1)
L_READ=$(grep -n 'json.load(f)' notekeeper/storage.py | cut -d: -f1)
L_SYNCED=$(grep -n 'print(f"synced' notekeeper/cli.py | cut -d: -f1)
L_REMOTE=$(grep -n 's.add_argument("remote"' notekeeper/cli.py | cut -d: -f1)
for v in "$L_MERGE" "$L_CMP" "$L_SORT" "$L_WLOCAL" "$L_RET" "$L_NOW" "$L_READ" "$L_SYNCED" "$L_REMOTE"; do
  [ -n "$v" ] || { echo "setup: fixture layout changed, line lookup failed" >&2; exit 1; }
done

nk_review_pool <<EOF
- [low] notekeeper/sync.py:${L_CMP} \`updated_at\` has one-second resolution; two edits in the same second resolve silently to the local copy with no message to the user.
- [low] tests/test_sync.py: no unit test for equal \`updated_at\` values; only the e2e scenario sync-offline-edit covers the tie.
- [low] notekeeper/sync.py:${L_SORT} merged notes are sorted by id, so \`ls\` after a sync no longer lists notes in the order they were added.
- [medium] notekeeper/sync.py:${L_MERGE} a note deleted on one device comes back on the next sync because the other side's copy is merged in again (no tombstones).
- [low] notekeeper/sync.py:${L_WLOCAL} the local file is written before the remote one; if the remote write fails the two disagree until the next sync.
- [low] notekeeper/cli.py:${L_SYNCED} "synced 1 notes": pluralise the message.
- [low] notekeeper/sync.py:${L_RET} \`sync()\` returns every merged note; the CLI can't report how many notes actually changed.
- [low] notekeeper/notes.py:${L_NOW} \`updated_at\` comes from the device's wall clock; a device whose clock runs ahead wins every conflict.
- [low] notekeeper/storage.py:${L_READ} \`read_json\` lets JSONDecodeError through; a truncated remote snapshot prints a traceback instead of a message.
- [low] notekeeper/sync.py:${L_CMP} a remote note without \`updated_at\` (snapshots from 0.1) raises KeyError mid-merge.
- [low] notekeeper/cli.py:${L_REMOTE} \`remote\` help ("remote snapshot file") doesn't say the file is JSON or that it is overwritten.
- [low] README.md: the sync example doesn't say which copy is kept when a note was changed on both sides.
EOF

rmdir validation 2>/dev/null || true  # no validation reports in this repo
nk_finalize "notekeeper 0.3.0"
