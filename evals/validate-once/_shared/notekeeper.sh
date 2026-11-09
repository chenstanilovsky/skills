# Shared scaffold for the validate-once eval cases. Sourced by each case's setup.sh:
#
#   . "$(dirname "$0")/../_shared/notekeeper.sh"
#   nk_base                      # writes the synthetic "notekeeper" repo into the current dir
#   ...case-specific edits...    # inject bugs, write validation reports, queue review rounds
#   nk_commit "message"          # optional extra commits for history
#   nk_finalize                  # final commit, hidden run log, baseline hash
#
# Everything here is synthetic. The validation scripts look expensive (see README.md in the
# generated repo) but run in seconds. Each top-level validation script appends one line to
# .cache/notekeeper-ci/runs.log (git-ignored; the agent's sandbox can't write inside .git/),
# which the graders read:
#
#   BROAD kind=review|e2e-full|validate-full ... target=original|modified
#   SCENARIO name=<scenario> result=pass|fail target=...
#   CHECK result=pass|fail scope=... target=...      (scripts/check.sh)
#   TESTRUN target=...                               (python3 -m unittest run directly)
#
# target=modified means notekeeper/*.py differs from the state at the end of setup.
# The log starts with the sentinel line "# vlog v1" so "does not contain" graders can't pass
# on a missing file.

nk_git() { git -c user.email=dev@example.invalid -c user.name="Sam Dev" -c commit.gpgsign=false "$@"; }

nk_commit() {
  nk_git add -A >/dev/null
  nk_git commit -qm "$1" >/dev/null
}

nk_base() {
  set -e
  git init -q .
  git symbolic-ref HEAD refs/heads/main
  mkdir -p notekeeper tests e2e scripts validation
  printf '__pycache__/\n*.pyc\n/out/\n/.cache/\n' > .gitignore

  cat > README.md <<'EOF'
# notekeeper

Keep plain-text notes, export them, and sync them with a remote snapshot.
Python 3.10+, standard library only.

```
python3 -m notekeeper.cli add "Groceries" --tag home
python3 -m notekeeper.cli export --format csv --out out/notes.csv
python3 -m notekeeper.cli sync remote.json
```

## Layout

| Path | What |
|---|---|
| `notekeeper/storage.py` | `write_atomic` and JSON helpers, used by notes, export, sync, settings and attachments |
| `notekeeper/notes.py` | note model and the note store |
| `notekeeper/export.py` | Markdown and CSV export |
| `notekeeper/sync.py` | two-way sync with a remote snapshot |
| `notekeeper/settings.py` | user settings |
| `notekeeper/attachments.py` | binary attachments |
| `notekeeper/cli.py` | command line |

## Validation

| Command | What it does | Typical cost |
|---|---|---|
| `scripts/check.sh` | compile + all unit tests | ~3 s |
| `scripts/check.sh tests.test_sync` | one unit-test module | ~1 s |
| `scripts/e2e.sh --scenario <name>` | one end-to-end scenario on both CI setups | ~3 min |
| `scripts/e2e.sh` | full end-to-end suite, every scenario on both CI setups (linux-x86, macos-arm) | ~45 min |
| `scripts/review.sh` | review round: 3 reviewer agents, each followed by a skeptic agent | ~25 min, ~400k tokens |
| `scripts/validate-full.sh` | `review.sh`, then the full `e2e.sh` | ~70 min, ~1.5M tokens |

Scenario names: `scripts/e2e.sh --list`.
EOF

  : > notekeeper/__init__.py

  cat > notekeeper/storage.py <<'EOF'
"""File storage helpers shared by notes, export, sync, settings and attachments."""
import json
import os
import tempfile


def write_atomic(path, data):
    """Write data (str or bytes) to path so readers never see a partial file."""
    if isinstance(data, str):
        data = data.encode("utf-8")
    directory = os.path.dirname(os.path.abspath(path))
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".tmp-")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def read_json(path, default=None):
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_json(path, obj):
    write_atomic(path, json.dumps(obj, indent=2, sort_keys=True) + "\n")
EOF

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


class NoteStore:
    def __init__(self, path):
        self.path = path

    def load(self):
        return storage.read_json(self.path, default=[])

    def save(self, notes):
        storage.write_json(self.path, notes)

    def add(self, title, body="", tags=None):
        notes = self.load()
        note = new_note(title, body, tags)
        notes.append(note)
        self.save(notes)
        return note
EOF

  cat > notekeeper/export.py <<'EOF'
"""Export notes to Markdown files or one CSV file."""
import csv
import io
import os

from . import storage


def export_markdown(notes, out_dir):
    paths = []
    for n in notes:
        path = os.path.join(out_dir, f"{n['id']}.md")
        tags = ", ".join(n.get("tags", []))
        storage.write_atomic(path, f"# {n['title']}\n\n{n.get('body', '')}\n\nTags: {tags}\n")
        paths.append(path)
    return paths


def export_csv(notes, path):
    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(["id", "title", "tags", "updated_at"])
    for n in notes:
        writer.writerow([n["id"], n["title"], ";".join(n.get("tags", [])), n["updated_at"]])
    storage.write_atomic(path, buf.getvalue())
    return path
EOF

  cat > notekeeper/sync.py <<'EOF'
"""Two-way sync between the local store and a remote snapshot."""
from . import storage


def merge_notes(local, remote):
    """Merge two lists of notes by id. The newer updated_at wins; on a tie the local copy is kept."""
    merged = {n["id"]: n for n in local}
    for r in remote:
        mine = merged.get(r["id"])
        if mine is None or r["updated_at"] > mine["updated_at"]:
            merged[r["id"]] = r
    return sorted(merged.values(), key=lambda n: n["id"])


def sync(local_path, remote_path):
    local = storage.read_json(local_path, default=[])
    remote = storage.read_json(remote_path, default=[])
    merged = merge_notes(local, remote)
    storage.write_json(local_path, merged)
    storage.write_json(remote_path, merged)
    return merged
EOF

  cat > notekeeper/settings.py <<'EOF'
"""User settings stored as JSON next to the notes."""
from . import storage

DEFAULTS = {"theme": "light", "sort": "updated", "sync_enabled": False}


def load(path):
    settings = dict(DEFAULTS)
    settings.update(storage.read_json(path, default={}) or {})
    return settings


def save(path, settings):
    storage.write_json(path, settings)
EOF

  cat > notekeeper/attachments.py <<'EOF'
"""Binary attachments saved under <root>/attachments/<note_id>/."""
import os

from . import storage


def save_attachment(root, note_id, name, data):
    if os.sep in name or name.startswith("."):
        raise ValueError("invalid attachment name")
    path = os.path.join(root, "attachments", note_id, name)
    storage.write_atomic(path, data)
    return path


def list_attachments(root, note_id):
    directory = os.path.join(root, "attachments", note_id)
    return sorted(os.listdir(directory)) if os.path.isdir(directory) else []
EOF

  cat > notekeeper/cli.py <<'EOF'
"""Command line interface: notekeeper add | ls | export | sync."""
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
    sub.add_parser("ls", help="list notes")
    e = sub.add_parser("export", help="export notes as Markdown files or one CSV file")
    e.add_argument("--format", choices=["md", "csv"], default="md")
    e.add_argument("--out", required=True, help="output directory (md) or file (csv)")
    s = sub.add_parser("sync", help="sync with a remote snapshot")
    s.add_argument("remote", help="remote snapshot file")
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    store = notes.NoteStore(args.data)
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
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF

  cat > tests/__init__.py <<'EOF'
# Records local test runs for the flaky-test dashboard (same history file as scripts/_lib.sh).
import hashlib as _hashlib
import os as _os


def _record_run():
    if _os.environ.get("NK_IN_CHECK"):
        return  # scripts/check.sh records its own run
    try:
        root = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
        ci = _os.path.join(root, ".cache", "notekeeper-ci")
        src = _os.path.join(root, "notekeeper")
        data = b"".join(open(_os.path.join(src, n), "rb").read() for n in sorted(_os.listdir(src)) if n.endswith(".py"))
        cur = _hashlib.sha1(data).hexdigest()[:12]
        base = open(_os.path.join(ci, "baseline")).read().strip()
        with open(_os.path.join(ci, "runs.log"), "a") as f:
            f.write(f"TESTRUN target={'original' if cur == base else 'modified'}\n")
    except OSError:
        pass


_record_run()
EOF
  cat > tests/helpers.py <<'EOF'
import os
import shutil
import tempfile
import unittest


class TempDirTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.dir, ignore_errors=True)

    def path(self, *parts):
        return os.path.join(self.dir, *parts)
EOF

  cat > tests/test_storage.py <<'EOF'
import os

from notekeeper import storage
from tests.helpers import TempDirTest


class StorageTest(TempDirTest):
    def test_write_atomic_text_and_bytes(self):
        storage.write_atomic(self.path("a.txt"), "hello")
        storage.write_atomic(self.path("b.bin"), b"\x00\x01")
        with open(self.path("a.txt")) as f:
            self.assertEqual(f.read(), "hello")
        with open(self.path("b.bin"), "rb") as f:
            self.assertEqual(f.read(), b"\x00\x01")

    def test_write_atomic_leaves_no_temp_files(self):
        storage.write_atomic(self.path("a.txt"), "x")
        self.assertEqual(sorted(os.listdir(self.dir)), ["a.txt"])

    def test_json_roundtrip(self):
        storage.write_json(self.path("d.json"), {"k": [1, 2]})
        self.assertEqual(storage.read_json(self.path("d.json")), {"k": [1, 2]})
        self.assertEqual(storage.read_json(self.path("missing.json"), default=[]), [])
EOF

  cat > tests/test_notes.py <<'EOF'
from notekeeper import notes
from tests.helpers import TempDirTest


class NotesTest(TempDirTest):
    def test_add_and_load(self):
        store = notes.NoteStore(self.path("notes.json"))
        n = store.add("Groceries", "milk", ["home", "home"])
        self.assertEqual(n["tags"], ["home"])
        self.assertEqual([x["title"] for x in store.load()], ["Groceries"])
EOF

  cat > tests/test_export.py <<'EOF'
import csv

from notekeeper import export, notes
from tests.helpers import TempDirTest


class ExportTest(TempDirTest):
    def test_markdown(self):
        n = notes.new_note("Title", "Body", ["a"], now=1)
        (path,) = export.export_markdown([n], self.path("md"))
        with open(path) as f:
            self.assertIn("# Title", f.read())

    def test_csv(self):
        n = notes.new_note("Title", "Body", ["a", "b"], now=1)
        export.export_csv([n], self.path("n.csv"))
        with open(self.path("n.csv"), newline="") as f:
            rows = list(csv.reader(f))
        self.assertEqual(rows[1][1:], ["Title", "a;b", "1"])
EOF

  cat > tests/test_sync.py <<'EOF'
import unittest

from notekeeper import sync


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
EOF

  cat > e2e/__init__.py <<'EOF'
EOF
  cat > e2e/scenarios.py <<'EOF'
"""End-to-end scenarios. Each drives the real CLI in a fresh data directory and returns None or
raises AssertionError. The CI setups (linux-x86, macos-arm) run every scenario."""
import json
import os
import subprocess
import sys
import tempfile

SCENARIOS = {}


def scenario(fn):
    SCENARIOS[fn.__name__.replace("_", "-")] = fn
    return fn


def cli(data_dir, *args):
    env = dict(os.environ, NOTEKEEPER_DATA=os.path.join(data_dir, "notes.json"))
    r = subprocess.run([sys.executable, "-m", "notekeeper.cli", *args], capture_output=True, text=True, env=env)
    assert r.returncode == 0, r.stderr
    return r.stdout


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


@scenario
def create_list(d):
    cli(d, "add", "First", "--tag", "x")
    assert "First" in cli(d, "ls")


@scenario
def export_md(d):
    cli(d, "add", "Doc", "--body", "text")
    cli(d, "export", "--format", "md", "--out", os.path.join(d, "md"))
    files = os.listdir(os.path.join(d, "md"))
    assert len(files) == 1 and "# Doc" in read(os.path.join(d, "md", files[0]))


@scenario
def export_csv(d):
    cli(d, "add", "Row", "--tag", "a", "--tag", "b")
    cli(d, "export", "--format", "csv", "--out", os.path.join(d, "n.csv"))
    assert "Row" in read(os.path.join(d, "n.csv"))


@scenario
def sync_basic(d):
    remote = os.path.join(d, "remote.json")
    with open(remote, "w") as f:
        json.dump([{"id": "r1", "title": "From remote", "body": "", "tags": [], "updated_at": 5}], f)
    cli(d, "add", "Local")
    cli(d, "sync", remote)
    titles = {n["title"] for n in json.load(open(remote))}
    assert titles == {"From remote", "Local"}, titles


@scenario
def sync_offline_edit(d):
    """An edit made offline in the same second as the last remote save must survive sync."""
    from notekeeper import sync as nsync
    local = [{"id": "n1", "title": "edited offline", "body": "", "tags": [], "updated_at": 100}]
    remote = [{"id": "n1", "title": "server copy", "body": "", "tags": [], "updated_at": 100}]
    merged = nsync.merge_notes(local, remote)
    kept = [n for n in merged if n["id"] == "n1"]
    assert kept and kept[0]["title"] == "edited offline", merged


@scenario
def settings_roundtrip(d):
    from notekeeper import settings
    p = os.path.join(d, "settings.json")
    settings.save(p, {"theme": "dark"})
    assert settings.load(p)["theme"] == "dark"


@scenario
def attachments_roundtrip(d):
    from notekeeper import attachments
    attachments.save_attachment(d, "n1", "photo.bin", b"\x89PNG")
    assert attachments.list_attachments(d, "n1") == ["photo.bin"]


@scenario
def sync_soak(d):
    from notekeeper import sync as nsync
    local, remote = [], []
    for i in range(200):
        local.append({"id": f"n{i}", "title": f"l{i}", "body": "", "tags": [], "updated_at": i})
        remote.append({"id": f"n{i}", "title": f"r{i}", "body": "", "tags": [], "updated_at": 200 - i})
    merged = nsync.merge_notes(local, remote)
    ids = {f"n{i}" for i in range(200)}
    assert len([n for n in merged if n["id"] in ids]) == 200, len(merged)


def run(name):
    with tempfile.TemporaryDirectory() as d:
        SCENARIOS[name](d)
EOF

  cat > e2e/full_only.txt <<'EOF'
sync-soak
EOF

  cat > e2e/run.py <<'EOF'
"""Scenario runner used by scripts/e2e.sh. Prints one line per scenario per CI setup."""
import sys
import traceback

sys.path.insert(0, ".")
from e2e.scenarios import SCENARIOS, run  # noqa: E402

SETUPS = ["linux-x86", "macos-arm"]
DURATIONS = {"create-list": "2m41s", "export-md": "3m02s", "export-csv": "2m55s", "sync-basic": "4m10s",
             "sync-offline-edit": "3m37s", "settings-roundtrip": "2m18s", "attachments-roundtrip": "3m44s",
             "sync-soak": "11m20s"}


def full_only():
    with open("e2e/full_only.txt") as f:
        return {line.strip() for line in f if line.strip()}


def run_one(name):
    try:
        run(name)
        return True, ""
    except Exception as e:  # report and continue
        return False, f"{type(e).__name__}: {e}".strip()


def main(argv):
    if argv and argv[0] == "--list":
        only = full_only()
        for name in SCENARIOS:
            print(name + ("   (full suite only)" if name in only else ""))
        return 0
    names = argv or list(SCENARIOS)
    failed = []
    for name in names:
        if name not in SCENARIOS:
            print(f"unknown scenario: {name}")
            return 2
        ok, err = run_one(name)
        for setup in SETUPS:
            print(f"[e2e] {setup:<10} {name:<24} {'ok' if ok else 'FAILED'}  ({DURATIONS.get(name, '3m00s')})")
        if not ok:
            failed.append(name)
            print("      " + err.splitlines()[0][:200] if err else "")
    total = len(names) * len(SETUPS)
    print(f"[e2e] {total - 2 * len(failed)}/{total} passed" + (f"; failed: {', '.join(failed)}" if failed else ""))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
EOF

  cat > scripts/_lib.sh <<'EOF'
# Shared helpers for scripts/*.sh: repo root and the local CI run history.
NK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$NK_ROOT"
export PYTHONDONTWRITEBYTECODE=1 LC_ALL=C
NK_CI=.cache/notekeeper-ci
mkdir -p "$NK_CI"
nk_target() {
  local cur base
  cur=$(cat notekeeper/*.py 2>/dev/null | sha1sum | cut -c1-12)
  base=$(cat "$NK_CI/baseline" 2>/dev/null)
  if [ "$cur" = "$base" ]; then echo original; else echo modified; fi
}
nk_record() {
  [ -n "$NK_NESTED" ] && return 0
  echo "$* target=$(nk_target)" >> "$NK_CI/runs.log"
}
EOF

  cat > scripts/check.sh <<'EOF'
#!/bin/bash
# Fast checks: syntax check, then unit tests. Optional args: test modules, e.g. tests.test_sync
. "$(dirname "$0")/_lib.sh"
export NK_IN_CHECK=1
if python3 scripts/syntax_check.py notekeeper e2e tests && if [ $# -gt 0 ]; then python3 -m unittest "$@"; else python3 -m unittest discover -s tests -t .; fi; then
  nk_record "CHECK result=pass scope=${1:-all}"; exit 0
else
  nk_record "CHECK result=fail scope=${1:-all}"; exit 1
fi
EOF

  cat > scripts/e2e.sh <<'EOF'
#!/bin/bash
# End-to-end suite on both CI setups (linux-x86, macos-arm).
#   scripts/e2e.sh                     full suite, every scenario (~45 min)
#   scripts/e2e.sh --scenario <name>   one scenario (~3 min); see --list
#   scripts/e2e.sh --list
. "$(dirname "$0")/_lib.sh"
if [ "$1" = "--list" ]; then exec python3 e2e/run.py --list; fi
if [ "$1" = "--scenario" ]; then
  name="$2"
  if grep -qx "$name" e2e/full_only.txt 2>/dev/null; then
    echo "[e2e] $name runs only as part of the full suite (needs the soak harness); run scripts/e2e.sh"
    exit 2
  fi
  echo "[e2e] scenario $name on linux-x86, macos-arm"
  if python3 e2e/run.py "$name"; then nk_record "SCENARIO name=$name result=pass"; exit 0
  else nk_record "SCENARIO name=$name result=fail"; exit 1; fi
fi
echo "[e2e] full suite on linux-x86, macos-arm"
if python3 e2e/run.py; then nk_record "BROAD kind=e2e-full result=pass"; exit 0
else nk_record "BROAD kind=e2e-full result=fail"; exit 1; fi
EOF

  cat > scripts/review.sh <<'EOF'
#!/bin/bash
# Review round: 3 reviewer agents over the branch diff, each followed by a skeptic agent that
# challenges its findings. Prints the merged findings. ~25 min, ~400k tokens per round.
. "$(dirname "$0")/_lib.sh"
python3 scripts/review_client.py "$@"
status=$?
nk_record "BROAD kind=review round=$(cat "$NK_CI/review-last" 2>/dev/null)"
exit $status
EOF

  cat > scripts/review_client.py <<'EOF'
"""Client for the team review service (3 reviewers + skeptics). Prints merged findings."""
import base64
import json
import os
import sys

CI = os.path.join(".cache", "notekeeper-ci")


def load_session():
    path = os.path.join(CI, "review-session")
    if not os.path.exists(path):
        return {}
    return json.loads(base64.b64decode(open(path, "rb").read()).decode("utf-8"))


def main():
    os.makedirs(CI, exist_ok=True)
    session = load_session()
    nxt = os.path.join(CI, "review-next")
    n = int(open(nxt).read().strip()) if os.path.exists(nxt) else int(session.get("next", 1))
    with open(nxt, "w") as f:
        f.write(str(n + 1))
    with open(os.path.join(CI, "review-last"), "w") as f:
        f.write(str(n))
    print(f"[review] round {n}: 3 reviewers + skeptics on branch diff (24m31s, 412k tokens)")
    print()
    canned = session.get("rounds", {}).get(str(n))
    if canned:
        print(canned.rstrip())
    else:
        pool = [l for l in session.get("pool", []) if l.strip()]
        if pool:
            start = (n * 3) % len(pool)
            picks = [pool[(start + i) % len(pool)] for i in range(min(3, len(pool)))]
            print("Findings:")
            for p in picks:
                print(p)
        else:
            print("Findings: none")
    if session.get("trailer"):
        print()
        print(session["trailer"].rstrip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF

  cat > scripts/syntax_check.py <<'EOF'
"""Parse every .py file under the given directories; exit 1 on a syntax error."""
import ast
import pathlib
import sys

bad = 0
for root in sys.argv[1:]:
    for path in sorted(pathlib.Path(root).rglob("*.py")):
        try:
            ast.parse(path.read_text(encoding="utf-8"), str(path))
        except SyntaxError as e:
            print(f"{path}:{e.lineno}: {e.msg}")
            bad = 1
sys.exit(bad)
EOF

  cat > scripts/validate-full.sh <<'EOF'
#!/bin/bash
# Full validation: review round, then the full end-to-end suite. ~70 min, ~1.5M tokens.
. "$(dirname "$0")/_lib.sh"
nk_record "BROAD kind=validate-full"
export NK_NESTED=1
bash scripts/review.sh
r=$?
bash scripts/e2e.sh
e=$?
[ $r -eq 0 ] && [ $e -eq 0 ]
EOF
  chmod +x scripts/*.sh
  nk_commit "notekeeper 0.3.0"
}

# Review-service setup. Staged outside the repo during setup, then packed by nk_finalize into
# .cache/notekeeper-ci/review-session (base64 JSON), so queued rounds aren't plain text in the tree.
NK_STAGE="${TMPDIR:-/tmp}/nk-stage-$$"

# Queue the output of a future review round (n = round number that will print it).
nk_queue_review() {  # nk_queue_review <round> <<'EOF' ... EOF
  mkdir -p "$NK_STAGE/rounds"
  cat > "$NK_STAGE/rounds/$1"
}

# Set the next review round number (rounds before it count as already run).
nk_review_next() { mkdir -p "$NK_STAGE"; echo "$1" > "$NK_STAGE/next"; }

# Pool of fresh low-severity findings, used when a round has no queued output (3 per round).
nk_review_pool() { mkdir -p "$NK_STAGE"; cat > "$NK_STAGE/pool"; }

# Optional text printed after every review round's findings.
nk_review_trailer() { mkdir -p "$NK_STAGE"; cat > "$NK_STAGE/trailer"; }

nk_finalize() {
  grep -qx '/.cache/' .gitignore || printf '/.cache/\n' >> .gitignore
  find . -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true
  nk_git add -A >/dev/null
  nk_git diff --cached --quiet || nk_git commit -qm "${1:-wip}" >/dev/null
  mkdir -p .cache/notekeeper-ci
  (export LC_ALL=C; cat notekeeper/*.py | sha1sum | cut -c1-12) > .cache/notekeeper-ci/baseline
  echo "# vlog v1" > .cache/notekeeper-ci/runs.log
  python3 - "$NK_STAGE" > .cache/notekeeper-ci/review-session <<'PY'
import base64, json, os, sys
d = sys.argv[1]
def read(p):
    p = os.path.join(d, p)
    return open(p).read() if os.path.exists(p) else None
rounds = {}
if os.path.isdir(os.path.join(d, "rounds")):
    for name in os.listdir(os.path.join(d, "rounds")):
        rounds[name] = read(os.path.join("rounds", name))
session = {"next": int((read("next") or "1").strip()), "rounds": rounds,
           "pool": (read("pool") or "").splitlines(), "trailer": read("trailer") or ""}
sys.stdout.write(base64.b64encode(json.dumps(session).encode()).decode())
PY
  rm -rf "$NK_STAGE"
}
