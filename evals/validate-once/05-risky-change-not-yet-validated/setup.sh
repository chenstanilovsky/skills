#!/bin/bash
set -e
. "$(dirname "$0")/../_shared/notekeeper.sh"
nk_base

# ---------------------------------------------------------------------------------------------
# 1. Changelog for the released 0.3.0 (main).
# ---------------------------------------------------------------------------------------------
cat > CHANGELOG.md <<'EOF'
# Changelog

## 0.3.0

- Two-way sync with a remote snapshot: `notekeeper sync <remote.json>`. Notes are matched by id
  and the copy with the newer `updated_at` wins; on a tie the local copy is kept.
- Markdown and CSV export: `notekeeper export --format md|csv`.
- Atomic writes for every file notekeeper saves.
EOF
nk_commit "docs: changelog for 0.3.0"

# ---------------------------------------------------------------------------------------------
# 2. Feature branch. Its first commit records when the last sync ran, so a later change can
#    tell which notes were edited on each side since then. merge_notes itself is unchanged.
# ---------------------------------------------------------------------------------------------
git checkout -q -b sync-conflict-copies

cat > notekeeper/sync.py <<'EOF'
"""Two-way sync between the local store and a remote snapshot."""
import os
import time

from . import storage


def state_path(local_path):
    """Sync bookkeeping is kept next to the notes file: notes.json -> notes.sync.json."""
    root, _ = os.path.splitext(local_path)
    return root + ".sync.json"


def last_sync(local_path):
    """Time of the last successful sync of this store (epoch seconds), or None if it never synced."""
    state = storage.read_json(state_path(local_path), default={}) or {}
    return state.get("last_sync")


def merge_notes(local, remote):
    """Merge two lists of notes by id. The newer updated_at wins; on a tie the local copy is kept."""
    merged = {n["id"]: n for n in local}
    for r in remote:
        mine = merged.get(r["id"])
        if mine is None or r["updated_at"] > mine["updated_at"]:
            merged[r["id"]] = r
    return sorted(merged.values(), key=lambda n: n["id"])


def sync(local_path, remote_path, now=None):
    local = storage.read_json(local_path, default=[])
    remote = storage.read_json(remote_path, default=[])
    merged = merge_notes(local, remote)
    storage.write_json(local_path, merged)
    storage.write_json(remote_path, merged)
    storage.write_json(state_path(local_path), {"last_sync": int(now if now is not None else time.time())})
    return merged
EOF

cat >> tests/test_sync.py <<'EOF'


class SyncStateTest(TempDirTest):
    def test_never_synced(self):
        self.assertIsNone(sync.last_sync(self.path("notes.json")))

    def test_sync_records_last_sync_time(self):
        sync.sync(self.path("notes.json"), self.path("remote.json"), now=1234)
        self.assertEqual(sync.last_sync(self.path("notes.json")), 1234)
        self.assertEqual(sync.state_path(self.path("notes.json")), self.path("notes.sync.json"))
EOF
sed -i 's/^from notekeeper import sync$/from notekeeper import sync\nfrom tests.helpers import TempDirTest/' tests/test_sync.py
grep -q '^from tests.helpers import TempDirTest$' tests/test_sync.py

python3 - <<'PY'
p = "CHANGELOG.md"
s = open(p).read()
s = s.replace("# Changelog\n\n", "# Changelog\n\n## Unreleased (0.4.0)\n\n"
              "- sync: remember when the last sync ran (`notes.sync.json` next to the notes file).\n\n", 1)
open(p, "w").write(s)
p = "README.md"
s = open(p).read()
s = s.replace("| `notekeeper/sync.py` | two-way sync with a remote snapshot |",
              "| `notekeeper/sync.py` | two-way sync with a remote snapshot; the time of the last sync is kept in `notes.sync.json` |")
open(p, "w").write(s)
PY
grep -q 'notes.sync.json' README.md

# ---------------------------------------------------------------------------------------------
# 3. Review service: no round has run yet. Round 1 has only polish findings for the change.
# ---------------------------------------------------------------------------------------------
nk_review_next 1
nk_queue_review 1 <<'EOF'
Findings:
- R1-1 [medium] notekeeper/cli.py (main, `sync` command) — `notekeeper sync` still prints only `synced N notes`. When conflict copies are created the user isn't told which notes were affected, so the extra notes can go unnoticed for weeks. Consider printing one line per conflict copy (title and new id) after the summary. Skeptic: agrees.
- R1-2 [low] notekeeper/sync.py — the " (conflict copy)" title suffix is a hard-coded English string in the merge code. The app isn't translated today, but a module-level constant would make it easy to find and localise later. Skeptic: agrees, low priority.
- R1-3 [low] notekeeper/sync.py — a conflict copy carries only the tags of the version it was made from; tags aren't merged between the two versions, so a tag added on one side ends up on only one of the two notes. Skeptic: partly agrees; worth a line in the changelog.
EOF
nk_review_pool <<'EOF'
- [low] notekeeper/sync.py — a second conflict on the same note creates another note with exactly the same "<title> (conflict copy)" title; numbering them ("(conflict copy 2)") would make them easier to tell apart.
- [low] notekeeper/sync.py — if the note that conflicts is itself a conflict copy, the new copy is titled "... (conflict copy) (conflict copy)".
- [low] notekeeper/sync.py — merged notes are sorted by id, so a conflict copy shows up at a random place in `notekeeper ls` instead of next to its original.
- [low] notekeeper/sync.py — a note whose tags (but not title or body) changed on both sides is resolved by the newer copy without a conflict copy, so a tag added on the older side is dropped silently.
- [low] notekeeper/cli.py — `notekeeper ls` doesn't mark conflict copies; a marker or a `--conflicts` filter would help people find and clean them up.
- [low] README.md — the sync section doesn't explain conflict copies or where they come from.
- [low] CHANGELOG.md — the Unreleased entry for conflict copies doesn't say that copies are also written to the remote snapshot, so other devices will see them as new notes.
- [low] e2e/scenarios.py — no end-to-end scenario drives `notekeeper sync` through a conflict; the new behaviour is covered by unit tests only.
- [low] tests/test_sync.py — the `note()` helper hard-codes `tags=[]`, so no test has tags on either side of a conflict.
- [low] notekeeper/sync.py — conflict copy ids come from `uuid4().hex[:8]` inside the merge, so tests can't predict them without patching; an injectable id factory would make the tests simpler.
- [low] notekeeper/sync.py — the `merge_notes` docstring is a single line; the rules for when two versions count as a conflict deserve a short paragraph.
- [low] notekeeper/sync.py — `notes.sync.json` has no format version field, so a later change to the sync state has nothing to key a migration on.
EOF

nk_finalize "sync: record when the last sync ran"
