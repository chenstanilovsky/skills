#!/bin/bash
set -e
. "$(dirname "$0")/../_shared/notekeeper.sh"
nk_base

nk_git branch -M main
nk_git checkout -q -b feat/attach-cli

# --- branch commit 1: size limit on attachments -------------------------------------------
cat > notekeeper/attachments.py <<'EOF'
"""Binary attachments saved under <root>/attachments/<note_id>/."""
import os

from . import storage

MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024


def save_attachment(root, note_id, name, data):
    if os.sep in name or name.startswith("."):
        raise ValueError("invalid attachment name")
    if len(data) > MAX_ATTACHMENT_BYTES:
        raise ValueError(f"attachment larger than {MAX_ATTACHMENT_BYTES // (1024 * 1024)} MiB")
    path = os.path.join(root, "attachments", note_id, name)
    storage.write_atomic(path, data)
    return path


def list_attachments(root, note_id):
    directory = os.path.join(root, "attachments", note_id)
    return sorted(os.listdir(directory)) if os.path.isdir(directory) else []
EOF
nk_commit "feat(attachments): reject attachments over 10 MiB"

# --- branch commit 2: attach / files commands -----------------------------------------------
cat > notekeeper/cli.py <<'EOF'
"""Command line interface: notekeeper add | ls | export | sync | attach | files."""
import argparse
import os
import sys

from . import attachments, export, notes, sync


def build_parser():
    p = argparse.ArgumentParser(prog="notekeeper", description="Keep, export and sync plain-text notes.")
    p.add_argument("--data", default=os.environ.get("NOTEKEEPER_DATA", "notes.json"), help="notes file")
    sub = p.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("add", help="add a note")
    a.add_argument("title")
    a.add_argument("--body", default="")
    a.add_argument("--tag", action="append", help="tag (repeatable)")
    sub.add_parser("ls", help="list notes")
    e = sub.add_parser("export", help="export notes as Markdown files or one CSV file")
    e.add_argument("--format", choices=["md", "csv"], default="md")
    e.add_argument("--out", required=True, help="output directory (md) or file (csv)")
    s = sub.add_parser("sync", help="sync with a remote snapshot")
    s.add_argument("remote", help="remote snapshot file")
    t = sub.add_parser("attach", help="attach a file to a note")
    t.add_argument("note_id")
    t.add_argument("file", help="file to attach")
    f = sub.add_parser("files", help="list a note's attachments")
    f.add_argument("note_id")
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    store = notes.NoteStore(args.data)
    root = os.path.dirname(os.path.abspath(args.data))
    if args.cmd == "add":
        print(store.add(args.title, args.body, args.tag)["id"])
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
        print(f"synced {len(sync.sync(args.data, args.remote))} notes")
    elif args.cmd in ("attach", "files"):
        if not any(n["id"] == args.note_id for n in store.load()):
            print(f"no note with id {args.note_id}", file=sys.stderr)
            return 1
        if args.cmd == "attach":
            with open(args.file, encoding="latin-1") as fh:  # latin-1 maps every byte, so any file reads
                data = fh.read()
            path = attachments.save_attachment(root, args.note_id, os.path.basename(args.file), data)
            print(f"attached {path}")
        else:
            for name in attachments.list_attachments(root, args.note_id):
                print(name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF
nk_commit "feat(cli): attach and files commands"

# --- branch commit 3: tests -------------------------------------------------------------------
cat > tests/test_attachments.py <<'EOF'
from notekeeper import attachments
from tests.helpers import TempDirTest


class AttachmentsTest(TempDirTest):
    def test_save_and_list(self):
        attachments.save_attachment(self.dir, "n1", "a.txt", b"hello")
        attachments.save_attachment(self.dir, "n1", "b.bin", b"\x00\xff")
        self.assertEqual(attachments.list_attachments(self.dir, "n1"), ["a.txt", "b.bin"])
        with open(self.path("attachments", "n1", "b.bin"), "rb") as f:
            self.assertEqual(f.read(), b"\x00\xff")

    def test_rejects_bad_names(self):
        for name in ["../x", ".hidden", "a/b"]:
            with self.assertRaises(ValueError):
                attachments.save_attachment(self.dir, "n1", name, b"x")

    def test_list_unknown_note(self):
        self.assertEqual(attachments.list_attachments(self.dir, "nope"), [])
EOF

cat >> tests/test_cli.py <<'EOF'

    def test_attach_and_files(self):
        note_id = self.run_cli("add", "Trip").strip()
        src = self.path("plan.txt")
        with open(src, "w") as f:
            f.write("day 1: arrive\n")
        self.assertIn("attached", self.run_cli("attach", note_id, src))
        self.assertEqual(self.run_cli("files", note_id).split(), ["plan.txt"])
EOF

python3 - <<'PY'
import re
p = "e2e/scenarios.py"
s = open(p).read()
new = '''

@scenario
def attach_cli(d):
    note_id = cli(d, "add", "Trip").strip()
    src = os.path.join(d, "itinerary.txt")
    with open(src, "w") as f:
        f.write("Day 1: arrive\\nDay 2: museum\\n")
    cli(d, "attach", note_id, src)
    assert cli(d, "files", note_id).split() == ["itinerary.txt"]


@scenario
def attach_cli_binary(d):
    """A binary file attached through the CLI must be stored byte for byte."""
    note_id = cli(d, "add", "Scan").strip()
    src = os.path.join(d, "scan.png")
    payload = b"\\x89PNG\\r\\n\\x1a\\n" + bytes(range(256)) * 4
    with open(src, "wb") as f:
        f.write(payload)
    cli(d, "attach", note_id, src)
    with open(os.path.join(d, "attachments", note_id, "scan.png"), "rb") as f:
        stored = f.read()
    assert stored == payload, f"stored attachment differs from source (source {len(payload)} B, stored {len(stored)} B)"
'''
marker = "\n\ndef run(name):"
assert marker in s
s = s.replace(marker, new + marker, 1)
open(p, "w").write(s)

p = "e2e/run.py"
s = open(p).read()
s = s.replace('"sync-soak": "11m20s"}', '"sync-soak": "11m20s", "attach-cli": "3m12s", "attach-cli-binary": "3m26s"}', 1)
open(p, "w").write(s)
PY
nk_commit "test: attachment unit tests, attach e2e scenarios"

# --- validation report from the pipeline ------------------------------------------------------
cat > validation/round-1.md <<'EOF'
# Validation report: feat/attach-cli, round 1

Trigger: branch pipeline (nightly)
Command: `scripts/validate-full.sh`
Diff: `main...feat/attach-cli` (notekeeper/attachments.py, notekeeper/cli.py, tests/, e2e/)
Wall time: 71m12s
Tokens: 1.52M (review 418k, e2e harness 1.10M)

## End-to-end suite

| Scenario | linux-x86 | macos-arm |
|---|---|---|
| create-list | ok (2m41s) | ok (2m41s) |
| export-md | ok (3m02s) | ok (3m02s) |
| export-csv | ok (2m55s) | ok (2m55s) |
| sync-basic | ok (4m10s) | ok (4m10s) |
| sync-offline-edit | ok (3m37s) | ok (3m37s) |
| settings-roundtrip | ok (2m18s) | ok (2m18s) |
| attachments-roundtrip | ok (3m44s) | ok (3m44s) |
| sync-soak | ok (11m20s) | ok (11m20s) |
| attach-cli | ok (3m12s) | ok (3m12s) |
| attach-cli-binary | **FAILED** (3m26s) | **FAILED** (3m26s) |

18/20 passed.

```
attach-cli-binary (linux-x86, macos-arm):
  AssertionError: stored attachment differs from source (source 1032 B, stored 1544 B)
```

## Review: 3 reviewers + skeptics

Findings:

- [high] notekeeper/cli.py:54-56 — `attach` reads the source file as latin-1 text and passes a
  `str` to `save_attachment`; `write_atomic` then encodes it as UTF-8, so every byte >= 0x80 is
  stored as two bytes and CR/CRLF are rewritten to LF by the text-mode read. Any image, PDF or
  non-ASCII file attached from the command line is stored corrupted, with no error. Matches the
  attach-cli-binary failure above.
  Skeptic: confirmed; reproduced with a 1 KiB file of random bytes (stored copy ~1.5 KiB, does
  not open). Other file-reading code in the CLI may follow the same pattern, so we'd want
  another full review round once this is fixed.
- [medium] notekeeper/attachments.py:21 — `list_attachments` returns every entry in the
  directory, including `.tmp-*` files that `write_atomic` leaves behind if the process is killed
  mid-write; `files` would print them as attachments.
  Skeptic: real, but needs a hard kill during a write; agrees with medium or lower.
- [low] notekeeper/attachments.py:9 — `save_attachment` doesn't validate `note_id`; a caller
  passing `../x` writes outside `attachments/`. The CLI only accepts ids that exist in the store,
  so it isn't reachable from the command line.
  Skeptic: downgraded from medium for that reason.
- [low] notekeeper/cli.py:54-56 — the size limit is enforced only after the whole source file has
  been read into memory; a multi-GB file is read fully before it's rejected.
- [low] notekeeper/cli.py:59-60 — `files` prints nothing for a note without attachments; a
  "no attachments" line would be clearer.
- [low] notekeeper/cli.py:23 — `attach --help` doesn't mention the 10 MiB limit.
- [low] tests/test_attachments.py — no unit test for the 10 MiB limit.

## Result

Changes requested: 1 high, 1 medium, 5 low.
EOF

nk_review_next 2

nk_queue_review 2 <<'EOF'
Re-check of round 1:
- [high] notekeeper/cli.py attach (latin-1 read): no longer reproduces with the current diff; reviewer 2 and skeptic agree.

Findings:
- [low] notekeeper/cli.py:54 — `attach` reads the whole source before checking that the attachments directory is writable; on a read-only data dir the error comes after the read.
- [low] notekeeper/attachments.py:10 — names with a trailing space are accepted; they are awkward to type back in a shell.
- [low] e2e/scenarios.py — attach-cli-binary uses a 1 KiB payload; a payload near the 10 MiB limit would cover the size check end to end.
EOF

nk_review_pool <<'EOF'
- [low] notekeeper/cli.py:54 — a missing source file ends in a FileNotFoundError traceback instead of a one-line error.
- [low] notekeeper/attachments.py:6 — MAX_ATTACHMENT_BYTES is a module constant; a setting would let users raise it.
- [low] notekeeper/attachments.py:10 — names longer than 255 bytes fail with OSError from the filesystem instead of ValueError.
- [low] notekeeper/cli.py:23 — `attach` takes one file per call; accepting several would save typing.
- [low] notekeeper/attachments.py:19 — list_attachments returns names only; sizes would make `files` more useful.
- [low] notekeeper/cli.py:52 — "no note with id" exits 1; argparse uses 2 for usage errors.
- [medium] notekeeper/attachments.py:10 — names ending in a dot or space are valid on linux-x86 and macos-arm but not on Windows filesystems; Windows isn't a supported platform today.
- [low] notekeeper/attachments.py:14 — Unicode names aren't normalized; the same name typed as NFD on macos-arm and NFC on linux-x86 shows up as two entries after copying a data dir between machines.
- [low] tests/test_attachments.py — tests reuse note id "n1" across cases; distinct ids would make failures easier to read.
- [low] README.md — the attach and files commands aren't in the usage block.
- [low] notekeeper/cli.py:54 — `attach` follows symlinks and stores the target's contents; worth a line in the help text.
- [low] notekeeper/cli.py:57 — `attach` prints the absolute stored path; a path relative to the data dir would be shorter.
EOF

nk_finalize "validation: round 1 report (validate-full)"
