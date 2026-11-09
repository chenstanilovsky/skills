#!/bin/bash
set -e
. "$(dirname "$0")/../_shared/notekeeper.sh"
nk_base

# Integration branch is main; the feature work lives on offline-sync.
nk_git branch -M main
nk_git checkout -q -b offline-sync

cat > notekeeper/notes.py <<'EOF'
"""Note model and the on-disk note store."""
import time
import uuid

from . import storage


def new_note(title, body="", tags=None, now=None):
    return {
        "id": uuid.uuid4().hex[:8],
        "title": title,
        "body": body,
        "tags": sorted(set(tags or [])),
        "updated_at": int(now if now is not None else time.time()),
    }


def edited(note, title=None, body=None, now=None):
    """Return a copy of note with the given fields changed and a fresh updated_at."""
    out = dict(note)
    if title is not None:
        out["title"] = title
    if body is not None:
        out["body"] = body
    out["updated_at"] = int(now if now is not None else time.time())
    return out


class NoteStore:
    def __init__(self, path):
        self.path = path

    def load(self):
        return storage.read_json(self.path, default=[])

    def save(self, notes):
        storage.write_json(self.path, notes)

    def get(self, note_id):
        return next((n for n in self.load() if n["id"] == note_id), None)

    def add(self, title, body="", tags=None):
        notes = self.load()
        note = new_note(title, body, tags)
        notes.append(note)
        self.save(notes)
        return note

    def put(self, note):
        """Insert or replace a note by id."""
        notes = [n for n in self.load() if n["id"] != note["id"]]
        notes.append(note)
        self.save(notes)
        return note
EOF

cat > notekeeper/sync.py <<'EOF'
"""Two-way sync between the local store and a remote snapshot.

Edits made while offline are queued in a pending file next to the notes file. The next sync
applies them to the local store, merges the result with the remote snapshot and writes both.
"""
import os

from . import storage


def pending_path(local_path):
    root, _ = os.path.splitext(local_path)
    return root + ".pending.json"


def queue_offline_edit(local_path, note):
    """Queue an edit made while offline; it is applied on the next sync."""
    path = pending_path(local_path)
    pending = storage.read_json(path, default=[])
    pending.append(note)
    storage.write_json(path, pending)


def apply_pending(local, pending):
    """Apply queued edits to the local notes; a later edit to the same id replaces an earlier one."""
    by_id = {n["id"]: n for n in local}
    for edit in pending:
        by_id[edit["id"]] = edit
    return list(by_id.values())


def merge_notes(local, remote):
    """Merge two lists of notes by id. The newer updated_at wins; on a tie the local copy is kept."""
    merged = {n["id"]: n for n in local}
    for r in remote:
        mine = merged.get(r["id"])
        if mine is None or r["updated_at"] >= mine["updated_at"]:
            merged[r["id"]] = r
    return sorted(merged.values(), key=lambda n: n["id"])


def count_conflicts(local, remote):
    """Number of notes present on both sides with different content."""
    theirs = {n["id"]: n for n in remote}
    return sum(1 for n in local if n["id"] in theirs and theirs[n["id"]] != n)


def sync(local_path, remote_path):
    """Apply queued offline edits, merge with the remote snapshot and write both sides.

    Returns (merged notes, number of conflicts resolved).
    """
    pending_file = pending_path(local_path)
    local = apply_pending(storage.read_json(local_path, default=[]), storage.read_json(pending_file, default=[]))
    remote = storage.read_json(remote_path, default=[])
    conflicts = count_conflicts(local, remote)
    merged = merge_notes(local, remote)
    storage.write_json(local_path, merged)
    storage.write_json(remote_path, merged)
    if os.path.exists(pending_file):
        os.unlink(pending_file)
    return merged, conflicts
EOF

cat > notekeeper/cli.py <<'EOF'
"""Command line interface: notekeeper add | edit | ls | export | sync."""
import argparse
import os
import sys

from . import export, notes, sync


def build_parser():
    p = argparse.ArgumentParser(prog="notekeeper", description="Keep, export and sync plain-text notes.")
    p.add_argument("--data", default=os.environ.get("NOTEKEEPER_DATA", "notes.json"), help="notes file")
    sub = p.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("add", help="add a note")
    a.add_argument("title")
    a.add_argument("--body", default="")
    a.add_argument("--tag", action="append", help="tag (repeatable)")
    ed = sub.add_parser("edit", help="edit a note")
    ed.add_argument("id")
    ed.add_argument("--title")
    ed.add_argument("--body")
    ed.add_argument("--offline", action="store_true", help="queue the edit and apply it on the next sync")
    sub.add_parser("ls", help="list notes")
    e = sub.add_parser("export", help="export notes as Markdown files or one CSV file")
    e.add_argument("--format", choices=["md", "csv"], default="md")
    e.add_argument("--out", required=True, help="output directory (md) or file (csv)")
    s = sub.add_parser("sync", help="sync with a remote snapshot (applies queued offline edits first)")
    s.add_argument("remote", help="remote snapshot file")
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    store = notes.NoteStore(args.data)
    if args.cmd == "add":
        print(store.add(args.title, args.body, args.tag)["id"])
    elif args.cmd == "edit":
        note = store.get(args.id)
        if note is None:
            print(f"no note with id {args.id}", file=sys.stderr)
            return 1
        changed = notes.edited(note, title=args.title, body=args.body)
        if args.offline:
            sync.queue_offline_edit(args.data, changed)
        else:
            store.put(changed)
    elif args.cmd == "ls":
        for n in store.load():
            print(f"{n['id']}  {n['title']}")
    elif args.cmd == "export":
        items = store.load()
        if args.format == "csv":
            export.export_csv(items, args.out)
        else:
            export.export_markdown(items, args.out)
        print(f"exported {len(items)} notes")
    elif args.cmd == "sync":
        merged, conflicts = sync.sync(args.data, args.remote)
        print(f"synced {len(merged)} notes, {conflicts} conflicts resolved")
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF
nk_commit "sync: queue edits made offline and apply them on the next sync"

cat > tests/test_sync.py <<'EOF'
import os
import unittest

from notekeeper import storage, sync
from tests.helpers import TempDirTest


def note(i, title, t):
    return {"id": i, "title": title, "body": "", "tags": [], "updated_at": t}


class MergeTest(unittest.TestCase):
    def test_newer_remote_wins(self):
        merged = sync.merge_notes([note("a", "old", 1)], [note("a", "new", 2)])
        self.assertEqual(merged[0]["title"], "new")

    def test_newer_local_wins(self):
        merged = sync.merge_notes([note("a", "mine", 3)], [note("a", "theirs", 2)])
        self.assertEqual(merged[0]["title"], "mine")

    def test_union_of_ids(self):
        merged = sync.merge_notes([note("a", "x", 1)], [note("b", "y", 1)])
        self.assertEqual([n["id"] for n in merged], ["a", "b"])


class OfflineQueueTest(TempDirTest):
    def test_apply_pending_replaces_by_id(self):
        out = sync.apply_pending([note("a", "x", 1), note("b", "y", 1)], [note("a", "x2", 2)])
        self.assertEqual(sorted(n["title"] for n in out), ["x2", "y"])

    def test_count_conflicts(self):
        local = [note("a", "x", 1), note("c", "same", 1)]
        remote = [note("a", "y", 2), note("b", "z", 1), note("c", "same", 1)]
        self.assertEqual(sync.count_conflicts(local, remote), 1)

    def test_pending_edit_applied_on_sync(self):
        local, remote = self.path("notes.json"), self.path("remote.json")
        storage.write_json(local, [note("a", "draft", 1)])
        storage.write_json(remote, [note("a", "draft", 1)])
        sync.queue_offline_edit(local, note("a", "edited offline", 5))
        merged, conflicts = sync.sync(local, remote)
        self.assertEqual(merged[0]["title"], "edited offline")
        self.assertEqual(conflicts, 1)
        self.assertEqual(storage.read_json(remote)[0]["title"], "edited offline")
        self.assertFalse(os.path.exists(sync.pending_path(local)))
EOF

cat > tests/test_cli.py <<'EOF'
import contextlib
import io
import os

from notekeeper import cli
from tests.helpers import TempDirTest


class CliTest(TempDirTest):
    def run_cli(self, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            cli.main(["--data", self.path("notes.json"), *args])
        return out.getvalue()

    def test_add_ls_export(self):
        self.run_cli("add", "Hello", "--tag", "t")
        self.assertIn("Hello", self.run_cli("ls"))
        self.assertIn("exported 1 notes", self.run_cli("export", "--format", "csv", "--out", self.path("o.csv")))
        self.assertTrue(os.path.exists(self.path("o.csv")))

    def test_edit(self):
        nid = self.run_cli("add", "Hello").strip()
        self.run_cli("edit", nid, "--title", "Hi")
        self.assertIn("Hi", self.run_cli("ls"))

    def test_offline_edit_applied_on_sync(self):
        nid = self.run_cli("add", "Draft").strip()
        self.run_cli("edit", nid, "--title", "Final", "--offline")
        self.assertIn("Draft", self.run_cli("ls"))
        self.assertIn("synced 1 notes", self.run_cli("sync", self.path("remote.json")))
        self.assertIn("Final", self.run_cli("ls"))
EOF
nk_commit "tests: offline queue, conflict count and the edit command"

# Line numbers for the reports and the queued review rounds (the fix below changes no line count).
L_DOC=$(grep -n 'on a tie the local copy is kept' notekeeper/sync.py | cut -d: -f1)
L_CMP=$(grep -n '>= mine\["updated_at"\]' notekeeper/sync.py | cut -d: -f1)
L_REMOTE=$(grep -n 'storage.write_json(remote_path, merged)' notekeeper/sync.py | cut -d: -f1)
L_UNLINK=$(grep -n 'os.unlink(pending_file)' notekeeper/sync.py | cut -d: -f1)
L_PENDING=$(grep -n '^def pending_path' notekeeper/sync.py | cut -d: -f1)
L_APPLY=$(grep -n '^def apply_pending' notekeeper/sync.py | cut -d: -f1)
L_COUNT=$(grep -n '^def count_conflicts' notekeeper/sync.py | cut -d: -f1)
L_SYNCRET=$(grep -n 'Returns (merged notes' notekeeper/sync.py | cut -d: -f1)
L_CLISYNC=$(grep -n 'conflicts resolved' notekeeper/cli.py | cut -d: -f1)
L_CLIEDIT=$(grep -n 'sync.queue_offline_edit(args.data, changed)' notekeeper/cli.py | cut -d: -f1)
L_CLIEDITP=$(grep -n 'ed = sub.add_parser("edit"' notekeeper/cli.py | cut -d: -f1)
L_EDITED=$(grep -n '^def edited' notekeeper/notes.py | cut -d: -f1)
export L_DOC L_CMP L_REMOTE L_CLISYNC

# Round 1: the only full validation run so far, on the branch before the tie fix.
python3 - <<'PY'
import os
import subprocess
import sys

env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
out = subprocess.run([sys.executable, "e2e/run.py"], capture_output=True, text=True, env=env).stdout.rstrip()
if "14/16 passed; failed: sync-offline-edit" not in out:
    sys.exit("setup: unexpected round 1 end-to-end result:\n" + out)
L = {k: os.environ[k] for k in ("L_DOC", "L_CMP", "L_REMOTE", "L_CLISYNC")}
report = f"""# Validation report: offline-sync, round 1

Branch: offline-sync (against main)
Command: scripts/validate-full.sh
Review: round 1, 3 reviewers + skeptics on the branch diff (24m31s, 412k tokens)
End-to-end: full suite on linux-x86 and macos-arm (46m08s)

## End-to-end

14/16 passed. Failed: sync-offline-edit (linux-x86, macos-arm).

```
[e2e] full suite on linux-x86, macos-arm
{out}
```

## Review findings

- [high] notekeeper/sync.py:{L['L_CMP']} `merge_notes`: data loss. An edit made offline in the same second as
  the last remote save is overwritten by the server copy on the next sync. The comparison is
  `r["updated_at"] >= mine["updated_at"]`, so a tie goes to the remote note, while the docstring
  (sync.py:{L['L_DOC']}) says ties keep the local copy. This is the sync-offline-edit failure above.
- [low] notekeeper/sync.py:{L['L_REMOTE']} `sync`: the remote snapshot is written with `storage.write_json`
  (indent=2, sorted keys). For a 5k-note store the uploaded file is about 40% larger than a compact
  dump.
- [low] notekeeper/cli.py:{L['L_CLISYNC']} `sync`: prints only how many conflicts were resolved
  ("synced 12 notes, 3 conflicts resolved"), not which notes were replaced, so a user can't check
  what changed.

VERDICT: CHANGES REQUESTED. Re-run the full review after addressing these findings.
"""
with open("validation/round-1.md", "w") as f:
    f.write(report)
PY
nk_commit "validation: round 1 report for offline-sync"

# The [high] from round 1 is fixed, with a regression test. The two lows were left for later.
sed -i 's/r\["updated_at"\] >= mine\["updated_at"\]/r["updated_at"] > mine["updated_at"]/' notekeeper/sync.py
python3 - <<'PY'
path = "tests/test_sync.py"
src = open(path).read()
anchor = '        self.assertEqual([n["id"] for n in merged], ["a", "b"])\n'
add = '''
    def test_tie_keeps_local(self):
        # An offline edit saved in the same second as the remote copy must survive the merge.
        merged = sync.merge_notes([note("a", "mine", 5)], [note("a", "theirs", 5)])
        self.assertEqual(merged[0]["title"], "mine")
'''
assert src.count(anchor) == 1
open(path, "w").write(src.replace(anchor, anchor + add))
PY
L_TIETEST=$(grep -n 'def test_tie_keeps_local' tests/test_sync.py | cut -d: -f1)

python3 - <<'PY'
import os
import subprocess
import sys

env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
out = subprocess.run([sys.executable, "e2e/run.py"], capture_output=True, text=True, env=env).stdout.rstrip()
if not out.endswith("[e2e] 16/16 passed"):
    sys.exit("setup: end-to-end suite should pass after the tie fix:\n" + out)
r = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-t", ".", "-q"],
                   capture_output=True, text=True, env=env)
if r.returncode != 0:
    sys.exit("setup: unit tests should pass after the tie fix:\n" + r.stderr)
PY

nk_review_next 2
nk_queue_review 2 <<EOF
Resolved since round 1:
- [high] notekeeper/sync.py:${L_CMP} \`merge_notes\`: a tie now keeps the local note (\`>\` instead of \`>=\`), matching the docstring. Covered by tests/test_sync.py:${L_TIETEST} \`test_tie_keeps_local\`.

Still open from round 1:
- [low] notekeeper/sync.py:${L_REMOTE} \`sync\`: the remote snapshot is still written pretty-printed (indent=2, sorted keys), about 40% larger than a compact dump.
- [low] notekeeper/cli.py:${L_CLISYNC} \`sync\`: still prints only how many conflicts were resolved, not which notes were replaced.

Findings:
- [low] notekeeper/sync.py:${L_DOC} \`merge_notes\` docstring: "newer" is compared at whole-second resolution (\`updated_at\` is \`int(time.time())\`); say so, since that is why ties happen at all.
- [low] tests/test_sync.py:${L_TIETEST} \`test_tie_keeps_local\` covers \`merge_notes\` only; no test drives a tie through \`sync()\` with a queued offline edit.
EOF

nk_review_pool <<EOF
- [low] README.md: the \`edit\` command and the \`--offline\` flag are missing from the usage block.
- [low] notekeeper/sync.py:${L_PENDING} \`pending_path\` puts the queue next to the notes file; document where it lives.
- [low] notekeeper/cli.py:${L_CLIEDITP} \`edit\` help doesn't say that --title and --body are both optional.
- [low] notekeeper/sync.py:${L_COUNT} \`count_conflicts\` builds the remote index even when the local list is empty.
- [low] notekeeper/notes.py:${L_EDITED} \`edited()\` makes a shallow copy; the \`tags\` list is shared with the original note.
- [low] notekeeper/sync.py:${L_SYNCRET} \`sync()\` returns a bare tuple; a NamedTuple would read better at call sites.
- [low] notekeeper/cli.py:${L_CLISYNC} "1 conflicts resolved": pluralise the message.
- [low] e2e/scenarios.py: no scenario drives \`edit --offline\` through the CLI end to end.
- [medium] notekeeper/sync.py:${L_UNLINK} the pending file is removed with os.unlink after both writes; a crash between them re-applies the queue on the next sync (harmless today because edits replace by id, but fragile).
- [low] tests/test_cli.py: \`test_offline_edit_applied_on_sync\` doesn't check that the pending file is gone afterwards.
- [low] notekeeper/cli.py:${L_CLIEDIT} \`edit --offline\` prints nothing on success; echo the note id the way \`add\` does.
- [low] notekeeper/sync.py:${L_APPLY} \`apply_pending\` keeps only the last queued edit per note; correct today, but say so where the queue is written.
EOF

nk_review_trailer <<'EOF'
VERDICT: CHANGES REQUESTED. Re-run the full review after addressing these findings.
EOF

nk_finalize $'sync: keep the local note when timestamps tie\n\nFixes the [high] from validation round 1: merge_notes compared with >=, so an\noffline edit saved in the same second as the remote copy was overwritten.\nAdds test_tie_keeps_local. The two [low] findings from round 1 (remote\nsnapshot size, sync output) are left for a follow-up.'
