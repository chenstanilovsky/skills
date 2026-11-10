#!/bin/bash
set -e
. "$(dirname "$0")/../_shared/notekeeper.sh"
nk_base

# Integration branch is main.
nk_git branch -M main

# On main: the settings and attachments scenarios moved to the full suite (they need per-setup
# user profiles), so they can't be run one by one.
printf 'settings-roundtrip\nattachments-roundtrip\n' >> e2e/full_only.txt
python3 - <<'PY'
p = "scripts/e2e.sh"
s = open(p).read()
old = "runs only as part of the full suite (needs the soak harness); run scripts/e2e.sh"
new = "runs only as part of the full suite (needs the full-suite harness: soak runner, per-setup user profiles); run scripts/e2e.sh"
assert old in s
open(p, "w").write(s.replace(old, new))
p = "README.md"
s = open(p).read()
old = "Scenario names: `scripts/e2e.sh --list`.\n"
new = old + ("Scenarios marked `(full suite only)` there need the full-suite harness (soak runner, per-setup\n"
             "user profiles) and only run as part of `scripts/e2e.sh`.\n")
assert old in s
open(p, "w").write(s.replace(old, new))
PY
nk_commit "e2e: settings and attachments scenarios need per-setup user profiles; run them only in the full suite"

# Feature branch: export to another drive.
nk_git checkout -q -b export-to-drive

cat > notekeeper/export.py <<'EOF'
"""Export notes to Markdown files or one CSV file.

--out may point at any folder, including one on another drive or a network share; ~ is expanded.
"""
import csv
import io
import os

from . import storage


class ExportError(Exception):
    pass


def resolve_out(out, is_file):
    """Expand ~ in --out, create the target folder and check that it can be written, so an
    export to a drive that is missing or read-only fails before any file is written."""
    path = os.path.abspath(os.path.expanduser(out))
    folder = os.path.dirname(path) if is_file else path
    try:
        os.makedirs(folder, exist_ok=True)
    except OSError as e:
        raise ExportError(f"cannot create {folder}: {e.strerror}") from e
    if not os.access(folder, os.W_OK):
        raise ExportError(f"cannot write to {folder}")
    return path


def export_markdown(notes, out_dir):
    out_dir = resolve_out(out_dir, is_file=False)
    paths = []
    for n in notes:
        path = os.path.join(out_dir, f"{n['id']}.md")
        tags = ", ".join(n.get("tags", []))
        storage.write_atomic(path, f"# {n['title']}\n\n{n.get('body', '')}\n\nTags: {tags}\n")
        paths.append(path)
    return paths


def export_csv(notes, path):
    path = resolve_out(path, is_file=True)
    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(["id", "title", "tags", "updated_at"])
    for n in notes:
        writer.writerow([n["id"], n["title"], ";".join(n.get("tags", [])), n["updated_at"]])
    storage.write_atomic(path, buf.getvalue())
    return path
EOF

python3 - <<'PY'
p = "notekeeper/cli.py"
s = open(p).read()
old_exp = """        items = store.load()
        if args.format == "csv":
            export.export_csv(items, args.out)
        else:
            export.export_markdown(items, args.out)
        print(f"exported {len(items)} notes")
"""
new_exp = """        items = store.load()
        try:
            if args.format == "csv":
                export.export_csv(items, args.out)
            else:
                export.export_markdown(items, args.out)
        except export.ExportError as err:
            print(f"export failed: {err}", file=sys.stderr)
            return 1
        print(f"exported {len(items)} notes")
"""
assert old_exp in s
open(p, "w").write(s.replace(old_exp, new_exp))
PY

cat > tests/test_export.py <<'EOF'
import csv
import os
from unittest import mock

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

    def test_out_expands_home(self):
        n = notes.new_note("Title", "Body", [], now=1)
        with mock.patch.dict(os.environ, {"HOME": self.dir}):
            path = export.export_csv([n], "~/exports/n.csv")
        self.assertEqual(path, self.path("exports", "n.csv"))
        self.assertTrue(os.path.exists(path))

    def test_markdown_creates_missing_folder(self):
        n = notes.new_note("Title", "Body", [], now=1)
        (path,) = export.export_markdown([n], self.path("drive", "notes"))
        self.assertTrue(os.path.exists(path))
EOF

python3 - <<'PY'
p = "e2e/scenarios.py"
s = open(p).read()
anchor = "\n\ndef run(name):"
new = '''

@scenario
def export_other_folder(d):
    """--out points at a folder outside the data directory, as when exporting to a USB drive."""
    with tempfile.TemporaryDirectory() as other:
        cli(d, "add", "Trip", "--body", "packing list")
        target = os.path.join(other, "notekeeper-export")
        cli(d, "export", "--format", "md", "--out", target)
        files = os.listdir(target)
        assert len(files) == 1 and "# Trip" in read(os.path.join(target, files[0])), files
'''
assert anchor in s
s = s.replace(anchor, new + anchor, 1)
open(p, "w").write(s)
p = "e2e/run.py"
s = open(p).read()
old = '"sync-soak": "11m20s"}'
assert old in s
open(p, "w").write(s.replace(old, '"sync-soak": "11m20s", "export-other-folder": "3m21s"}'))
PY
nk_commit "export: --out may point at any folder or drive; expand ~ and check the folder first"

cat > notekeeper/storage.py <<'EOF'
"""File storage helpers shared by notes, export, sync, settings and attachments."""
import json
import os
import tempfile


def write_atomic(path, data):
    """Write data (str or bytes) to path so readers never see a partial file.

    The data is written to a temp file in the system temp directory and then moved into place,
    so half-written files never show up in the target folder (an export folder may be watched by
    a sync client or open in a file manager while the export runs).
    """
    if isinstance(data, str):
        data = data.encode("utf-8")
    directory = os.path.dirname(os.path.abspath(path))
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix="notekeeper-")
    with os.fdopen(fd, "wb") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def read_json(path, default=None):
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_json(path, obj):
    write_atomic(path, json.dumps(obj, indent=2, sort_keys=True) + "\n")
EOF
nk_commit "storage: write temp files outside the target folder so exports don't show half-written files"

# Line numbers for the report and the queued review rounds.
L_MKSTEMP=$(grep -n 'tempfile.mkstemp(prefix="notekeeper-")' notekeeper/storage.py | cut -d: -f1)
L_REPLACE=$(grep -n 'os.replace(tmp, path)' notekeeper/storage.py | cut -d: -f1)
L_WA=$(grep -n '^def write_atomic' notekeeper/storage.py | cut -d: -f1)
L_FSYNC=$(grep -n 'os.fsync(f.fileno())' notekeeper/storage.py | cut -d: -f1)
L_WJSON=$(grep -n '^def write_json' notekeeper/storage.py | cut -d: -f1)
L_OUTHELP=$(grep -n 'e.add_argument("--out"' notekeeper/cli.py | cut -d: -f1)
L_EXPFAIL=$(grep -n 'export failed:' notekeeper/cli.py | cut -d: -f1)
L_EXPOK=$(grep -n 'exported {len(items)} notes' notekeeper/cli.py | cut -d: -f1)
L_MDWRITE=$(grep -n 'storage.write_atomic(path, f"# ' notekeeper/export.py | cut -d: -f1)
L_RESOLVE=$(grep -n '^def resolve_out' notekeeper/export.py | cut -d: -f1)
L_ACCESS=$(grep -n 'os.access(folder, os.W_OK)' notekeeper/export.py | cut -d: -f1)
L_MAKEDIRS=$(grep -n 'os.makedirs(folder, exist_ok=True)' notekeeper/export.py | cut -d: -f1)
L_EXPMD=$(grep -n '^def export_markdown' notekeeper/export.py | cut -d: -f1)
L_SETLOAD=$(grep -n '^def load' notekeeper/settings.py | cut -d: -f1)
L_ATTSAVE=$(grep -n '^def save_attachment' notekeeper/attachments.py | cut -d: -f1)
export L_MKSTEMP L_REPLACE L_OUTHELP L_MDWRITE

python3 - <<'PY'
import os
import subprocess
import sys

env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
out = subprocess.run([sys.executable, "e2e/run.py"], capture_output=True, text=True, env=env).stdout.rstrip()
if "18/18 passed" not in out:
    sys.exit("setup: unexpected end-to-end result:\n" + out)
L = {k: os.environ[k] for k in ("L_MKSTEMP", "L_REPLACE", "L_OUTHELP", "L_MDWRITE")}
report = f"""# Validation report: export-to-drive, round 1

Branch: export-to-drive (against main)
Command: scripts/validate-full.sh
Review: round 1, 3 reviewers + skeptics on the branch diff (24m31s, 412k tokens)
End-to-end: full suite on linux-x86 and macos-arm (47m12s)

## End-to-end

18/18 passed.

```
[e2e] full suite on linux-x86, macos-arm
{out}
```

## Review findings

- [high] notekeeper/storage.py:{L['L_MKSTEMP']} `write_atomic`: exporting to another drive fails. Since this
  branch the temp file is created with `tempfile.mkstemp(prefix="notekeeper-")` in the system temp
  directory, and `os.replace` (storage.py:{L['L_REPLACE']}) can't move a file across filesystems, so every
  export to a USB drive, a network share or a second disk fails with EXDEV. Each failed write also
  leaves a `notekeeper-*` file behind in /tmp, because nothing removes the temp file when the write
  or the move fails. Root cause: `storage.write_atomic` must create the temp file next to the
  target (in the same directory) and remove it on failure. Neither CI setup writes to a second
  filesystem, which is why the end-to-end suite passed.

  ```
  $ python3 -m notekeeper.cli export --format md --out /media/usb/notes
  Traceback (most recent call last):
    ...
    File "notekeeper/storage.py", line {L['L_REPLACE']}, in write_atomic
      os.replace(tmp, path)
  OSError: [Errno 18] Invalid cross-device link: '/tmp/notekeeper-k2j9x1qa' -> '/media/usb/notes/3f9a1c2e.md'
  ```
- [low] notekeeper/cli.py:{L['L_OUTHELP']} `export --out` help doesn't say that the folder can be on another
  drive or that `~` is expanded.
- [low] notekeeper/export.py:{L['L_MDWRITE']} `export_markdown` overwrites existing `<id>.md` files in the
  target folder without saying so.

Verdict: changes requested (1 blocking finding).
"""
with open("validation/round-1.md", "w") as f:
    f.write(report)
PY

nk_review_next 2
nk_queue_review 2 <<EOF
Findings:
- [low] notekeeper/storage.py:${L_WA} \`write_atomic\`: the temp-file prefix doesn't say which file it belongs to; use the target's basename so a leftover file can be traced.
- [low] tests/test_storage.py: nothing covers a target on another filesystem; patch \`os.replace\` to raise EXDEV for moves between directories and check the result.
- [low] notekeeper/export.py:${L_ACCESS} \`resolve_out\`: \`os.access\` is advisory on network shares; the check can pass and the write still fail.
EOF

nk_review_pool <<EOF
- [low] README.md: the usage block doesn't show an export to another drive or \`~\` in \`--out\`.
- [low] notekeeper/cli.py:${L_EXPFAIL} "export failed: cannot write to ..." doesn't suggest checking that the drive is mounted.
- [low] notekeeper/export.py:${L_MAKEDIRS} \`resolve_out\` creates the target folder even when the export then fails, so an empty folder is left on the drive.
- [low] notekeeper/storage.py:${L_FSYNC} \`write_atomic\` fsyncs the file but not its directory; on some filesystems the rename may not survive a power cut.
- [low] notekeeper/export.py:${L_EXPMD} \`export_markdown\` prints nothing while it runs; a progress line would help for large exports to slow USB drives.
- [low] tests/test_export.py: \`test_out_expands_home\` patches HOME only; on Windows \`expanduser\` reads USERPROFILE.
- [low] notekeeper/cli.py:${L_EXPOK} the success message doesn't say where the notes were written.
- [low] notekeeper/settings.py:${L_SETLOAD} \`load\` silently keeps unknown keys from the settings file.
- [low] e2e/scenarios.py: \`export-other-folder\` exports to a folder on the same filesystem, so it can't catch cross-device problems.
- [low] notekeeper/export.py:${L_RESOLVE} \`resolve_out\` takes \`is_file\` as a positional flag; a keyword-only argument would read better at call sites.
- [low] notekeeper/storage.py:${L_WJSON} \`write_json\` always pretty-prints; exports of large note sets to slow drives would be smaller compact.
- [low] notekeeper/attachments.py:${L_ATTSAVE} \`save_attachment\` error says "invalid attachment name" without saying why.
- [medium] notekeeper/cli.py:${L_OUTHELP} \`export --out\` accepts an existing file for \`--format md\`; the error from makedirs is shown as "cannot create" without saying it is a file.
EOF

nk_finalize "validation: round 1 report for export-to-drive"
