#!/bin/bash
set -e
. "$(dirname "$0")/../_shared/notekeeper.sh"
nk_base

git checkout -q -b csv-export-polish

# ---------------------------------------------------------------------------------------------
# 1. Feature commit: body column and --fields for the CSV export (first version, as reviewed in
#    round 1: unquoted cells, KeyError on unknown field names, duplicate columns allowed).
# ---------------------------------------------------------------------------------------------
cat > notekeeper/export.py <<'EOF'
"""Export notes to Markdown files or one CSV file."""
import csv
import io
import os

from . import storage

# Column names for the CSV export, in default order.
CSV_FIELDS = ("id", "title", "body", "tags", "updated_at")


def export_markdown(notes, out_dir):
    paths = []
    for n in notes:
        path = os.path.join(out_dir, f"{n['id']}.md")
        tags = ", ".join(n.get("tags", []))
        storage.write_atomic(path, f"# {n['title']}\n\n{n.get('body', '')}\n\nTags: {tags}\n")
        paths.append(path)
    return paths


def _cell(note, field):
    if field == "tags":
        return ";".join(note.get("tags", []))
    return note[field]


def export_csv(notes, path, fields=None):
    fields = [f.strip() for f in fields.split(",")] if fields else list(CSV_FIELDS)
    buf = io.StringIO()
    # One note per line and no quote characters, so the file stays easy to grep.
    writer = csv.writer(buf, quoting=csv.QUOTE_NONE, escapechar="\\")
    writer.writerow(fields)
    for n in notes:
        writer.writerow([_cell(n, f) for f in fields])
    storage.write_atomic(path, buf.getvalue())
    return path
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
    e.add_argument("--out", required=True, help="output path")
    e.add_argument("--fields", help="csv only: comma-separated columns (default: id,title,body,tags,updated_at)")
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
            export.export_csv(items, args.out, args.fields)
        else:
            export.export_markdown(items, args.out)
        print(f"exported {len(items)} notes")
    elif args.cmd == "sync":
        print(f"synced {len(sync.sync(args.data, args.remote))} notes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF

cat > tests/test_export.py <<'EOF'
import csv

from notekeeper import export, notes
from tests.helpers import TempDirTest


def read_rows(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.reader(f))


class ExportTest(TempDirTest):
    def test_markdown(self):
        n = notes.new_note("Title", "Body", ["a"], now=1)
        (path,) = export.export_markdown([n], self.path("md"))
        with open(path) as f:
            self.assertIn("# Title", f.read())

    def test_csv(self):
        n = notes.new_note("Title", "Body", ["a", "b"], now=1)
        export.export_csv([n], self.path("n.csv"))
        rows = read_rows(self.path("n.csv"))
        self.assertEqual(rows[0], ["id", "title", "body", "tags", "updated_at"])
        self.assertEqual(rows[1][1:], ["Title", "Body", "a;b", "1"])

    def test_csv_fields_subset_in_given_order(self):
        n = notes.new_note("T", "B", ["x"], now=7)
        export.export_csv([n], self.path("n.csv"), fields="updated_at,title")
        self.assertEqual(read_rows(self.path("n.csv")), [["updated_at", "title"], ["7", "T"]])
EOF

python3 - <<'PY'
p = "README.md"
s = open(p).read()
s = s.replace(
    "python3 -m notekeeper.cli export --format csv --out out/notes.csv\n",
    "python3 -m notekeeper.cli export --format csv --out out/notes.csv\n"
    "python3 -m notekeeper.cli export --format csv --out out/titles.csv --fields id,title,tags\n",
)
s = s.replace("| `notekeeper/export.py` | Markdown and CSV export |",
              "| `notekeeper/export.py` | Markdown and CSV export (CSV columns: id, title, body, tags, updated_at) |")
s += """
## Validation reports

Reports from `scripts/validate-full.sh` runs on this branch are kept in `validation/round-N.md`.
"""
open(p, "w").write(s)
PY
nk_commit "feat(export): body column and --fields option for CSV export"
FEAT_SHA=$(git rev-parse --short HEAD)

# ---------------------------------------------------------------------------------------------
# 2. Round 1 report (validate-full on the feature commit).
# ---------------------------------------------------------------------------------------------
cat > validation/round-1.md <<'EOF'
# Validation report: round 1

| | |
|---|---|
| Branch | `csv-export-polish` |
| Commit | `@FEAT@` feat(export): body column and --fields option for CSV export |
| Run | `scripts/validate-full.sh` (review round 1, then the full e2e suite) |
| Wall time | 69m48s |
| Tokens | 1.49M |

## End-to-end: full suite on linux-x86, macos-arm

```
[e2e] full suite on linux-x86, macos-arm
[e2e] linux-x86  create-list              ok  (2m41s)
[e2e] macos-arm  create-list              ok  (2m41s)
[e2e] linux-x86  export-md                ok  (3m02s)
[e2e] macos-arm  export-md                ok  (3m02s)
[e2e] linux-x86  export-csv               ok  (2m55s)
[e2e] macos-arm  export-csv               ok  (2m55s)
[e2e] linux-x86  sync-basic               ok  (4m10s)
[e2e] macos-arm  sync-basic               ok  (4m10s)
[e2e] linux-x86  sync-offline-edit        ok  (3m37s)
[e2e] macos-arm  sync-offline-edit        ok  (3m37s)
[e2e] linux-x86  settings-roundtrip       ok  (2m18s)
[e2e] macos-arm  settings-roundtrip       ok  (2m18s)
[e2e] linux-x86  attachments-roundtrip    ok  (3m44s)
[e2e] macos-arm  attachments-roundtrip    ok  (3m44s)
[e2e] linux-x86  sync-soak                ok  (11m20s)
[e2e] macos-arm  sync-soak                ok  (11m20s)
[e2e] 16/16 passed
```

## Review: round 1 (3 reviewers + skeptics, 24m31s, 412k tokens)

Findings:
- R1-1 [high] notekeeper/export.py:32 — the writer uses `quoting=csv.QUOTE_NONE, escapechar="\\"`, so a comma, quote or newline in a title or body is written as a backslash escape instead of a quoted cell. Spreadsheet apps and `csv.reader` don't understand the escapes: `Rent, "May"` splits into two columns and a multi-line body splits into extra rows, so the export no longer round-trips (reproduced with a 3-line body: 1 note became 3 rows). Skeptic: agrees, data loss on re-import.
- R1-2 [medium] notekeeper/export.py:25 — `_cell` does `note[field]`, so `--fields id,titel` (typo) ends in a `KeyError` traceback after the output path was chosen, instead of a usage error naming the valid columns. Skeptic: agrees.
- R1-3 [low] notekeeper/export.py:29 — `--fields id,title,id` writes the `id` column twice; drop repeated names.
- R1-4 [low] e2e/scenarios.py — no scenario exports a title or body containing commas, quotes or newlines; the `export-csv` scenario only checks that the title appears in the file.

VERDICT: CHANGES REQUESTED. Re-run the full review after addressing these findings.
EOF
sed -i "s/@FEAT@/$FEAT_SHA/" validation/round-1.md
nk_commit "ci: validation round 1 report"

# ---------------------------------------------------------------------------------------------
# 3. Fix R1-1: let the csv module quote cells (QUOTE_MINIMAL).
# ---------------------------------------------------------------------------------------------
python3 - <<'PY'
p = "notekeeper/export.py"
s = open(p).read()
s = s.replace(
    '    # One note per line and no quote characters, so the file stays easy to grep.\n'
    '    writer = csv.writer(buf, quoting=csv.QUOTE_NONE, escapechar="\\\\")\n',
    '    # QUOTE_MINIMAL: cells with commas, quotes or newlines are quoted, so titles and bodies\n'
    '    # round-trip through spreadsheet apps and csv.reader.\n'
    '    writer = csv.writer(buf)\n',
)
open(p, "w").write(s)
PY
grep -q 'writer = csv.writer(buf)$' notekeeper/export.py
cat >> tests/test_export.py <<'EOF'

    def test_csv_quotes_commas_quotes_and_newlines(self):
        n = notes.new_note('Rent, "May"', "line one\nline two, with comma", [], now=1)
        export.export_csv([n], self.path("n.csv"))
        rows = read_rows(self.path("n.csv"))
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[1][1:3], ['Rent, "May"', "line one\nline two, with comma"])
EOF
nk_commit "fix(export): quote commas, quotes and newlines in CSV cells (R1-1)"
FIX1_SHA=$(git rev-parse --short HEAD)

# ---------------------------------------------------------------------------------------------
# 4. Fix R1-2 and R1-3: validate --fields up front, report a usage error, drop repeats.
# ---------------------------------------------------------------------------------------------
cat > notekeeper/export.py <<'EOF'
"""Export notes to Markdown files or one CSV file."""
import csv
import io
import os

from . import storage

# Column names for the CSV export, in default order.
CSV_FIELDS = ("id", "title", "body", "tags", "updated_at")


def export_markdown(notes, out_dir):
    paths = []
    for n in notes:
        path = os.path.join(out_dir, f"{n['id']}.md")
        tags = ", ".join(n.get("tags", []))
        storage.write_atomic(path, f"# {n['title']}\n\n{n.get('body', '')}\n\nTags: {tags}\n")
        paths.append(path)
    return paths


def parse_fields(spec):
    """Turn a --fields value such as "id,title" into a tuple of CSV column names."""
    if spec is None:
        return CSV_FIELDS
    fields = []
    for name in spec.split(","):
        name = name.strip()
        if not name:
            continue
        if name not in CSV_FIELDS:
            raise ValueError(f"unknown field {name!r}; choose from {', '.join(CSV_FIELDS)}")
        if name not in fields:
            fields.append(name)
    if not fields:
        raise ValueError("no fields given")
    return tuple(fields)


def _cell(note, field):
    if field == "tags":
        return ";".join(note.get("tags", []))
    return note.get(field, "")


def export_csv(notes, path, fields=CSV_FIELDS):
    buf = io.StringIO()
    # QUOTE_MINIMAL: cells with commas, quotes or newlines are quoted, so titles and bodies
    # round-trip through spreadsheet apps and csv.reader.
    writer = csv.writer(buf)
    writer.writerow(fields)
    for n in notes:
        writer.writerow([_cell(n, f) for f in fields])
    storage.write_atomic(path, buf.getvalue())
    return path
EOF

python3 - <<'PY'
p = "notekeeper/cli.py"
s = open(p).read()
s = s.replace(
    "    args = build_parser().parse_args(argv)\n",
    "    parser = build_parser()\n    args = parser.parse_args(argv)\n",
)
s = s.replace(
    "        if args.format == \"csv\":\n"
    "            export.export_csv(items, args.out, args.fields)\n",
    "        if args.format == \"csv\":\n"
    "            try:\n"
    "                fields = export.parse_fields(args.fields)\n"
    "            except ValueError as err:\n"
    "                parser.error(str(err))\n"
    "            export.export_csv(items, args.out, fields)\n",
)
open(p, "w").write(s)
PY
grep -q 'parser.error(str(err))' notekeeper/cli.py

python3 - <<'PY'
p = "tests/test_export.py"
s = open(p).read()
s = s.replace('fields="updated_at,title")', 'fields=export.parse_fields("updated_at,title"))')
s += '''
    def test_parse_fields(self):
        self.assertEqual(export.parse_fields(None), export.CSV_FIELDS)
        self.assertEqual(export.parse_fields("title,id,title"), ("title", "id"))
        with self.assertRaises(ValueError):
            export.parse_fields("id,titel")
        with self.assertRaises(ValueError):
            export.parse_fields(",")
'''
open(p, "w").write(s)
PY

cat >> tests/test_cli.py <<'EOF'

    def test_export_unknown_field_is_a_usage_error(self):
        with self.assertRaises(SystemExit) as cm, contextlib.redirect_stderr(io.StringIO()):
            self.run_cli("export", "--format", "csv", "--out", self.path("o.csv"), "--fields", "id,nope")
        self.assertEqual(cm.exception.code, 2)
        self.assertFalse(os.path.exists(self.path("o.csv")))
EOF
nk_commit "fix(cli): reject unknown --fields names with a usage error, drop repeated names (R1-2, R1-3)"
FIX2_SHA=$(git rev-parse --short HEAD)

# ---------------------------------------------------------------------------------------------
# 5. Fix R1-4: e2e scenario for commas, quotes and newlines.
# ---------------------------------------------------------------------------------------------
python3 - <<'PY'
p = "e2e/scenarios.py"
s = open(p).read()
new = '''@scenario
def export_csv_quoting(d):
    """Titles and bodies with commas, quotes and newlines survive a CSV round trip."""
    import csv
    cli(d, "add", 'Rent, "May"', "--body", "line one\\nline two, with comma")
    out = os.path.join(d, "q.csv")
    cli(d, "export", "--format", "csv", "--out", out)
    with open(out, newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    assert len(rows) == 2, rows
    assert rows[1][1:3] == ['Rent, "May"', "line one\\nline two, with comma"], rows


@scenario
def sync_basic(d):
'''
s = s.replace("@scenario\ndef sync_basic(d):\n", new, 1)
open(p, "w").write(s)
p = "e2e/run.py"
s = open(p).read()
s = s.replace('"export-csv": "2m55s", ', '"export-csv": "2m55s", "export-csv-quoting": "3m08s", ')
open(p, "w").write(s)
PY
grep -q 'def export_csv_quoting' e2e/scenarios.py
nk_commit "test(e2e): cover commas, quotes and newlines in CSV export (R1-4)"
FIX3_SHA=$(git rev-parse --short HEAD)

# ---------------------------------------------------------------------------------------------
# 6. Round 2 report (validate-full on the fixed branch).
# ---------------------------------------------------------------------------------------------
cat > validation/round-2.md <<'EOF'
# Validation report: round 2

| | |
|---|---|
| Branch | `csv-export-polish` |
| Commit | `@FIX3@` test(e2e): cover commas, quotes and newlines in CSV export (R1-4) |
| Run | `scripts/validate-full.sh` (review round 2, then the full e2e suite) |
| Wall time | 71m05s |
| Tokens | 1.52M |

## End-to-end: full suite on linux-x86, macos-arm

```
[e2e] full suite on linux-x86, macos-arm
[e2e] linux-x86  create-list              ok  (2m41s)
[e2e] macos-arm  create-list              ok  (2m41s)
[e2e] linux-x86  export-md                ok  (3m02s)
[e2e] macos-arm  export-md                ok  (3m02s)
[e2e] linux-x86  export-csv               ok  (2m55s)
[e2e] macos-arm  export-csv               ok  (2m55s)
[e2e] linux-x86  export-csv-quoting       ok  (3m08s)
[e2e] macos-arm  export-csv-quoting       ok  (3m08s)
[e2e] linux-x86  sync-basic               ok  (4m10s)
[e2e] macos-arm  sync-basic               ok  (4m10s)
[e2e] linux-x86  sync-offline-edit        ok  (3m37s)
[e2e] macos-arm  sync-offline-edit        ok  (3m37s)
[e2e] linux-x86  settings-roundtrip       ok  (2m18s)
[e2e] macos-arm  settings-roundtrip       ok  (2m18s)
[e2e] linux-x86  attachments-roundtrip    ok  (3m44s)
[e2e] macos-arm  attachments-roundtrip    ok  (3m44s)
[e2e] linux-x86  sync-soak                ok  (11m20s)
[e2e] macos-arm  sync-soak                ok  (11m20s)
[e2e] 18/18 passed
```

## Review: round 2 (3 reviewers + skeptics, 24m31s, 412k tokens)

Round 1 findings, re-checked:
- R1-1 [high] unquoted CSV cells: fixed in `@FIX1@`. All 3 reviewers confirm; titles and bodies with commas, quotes and newlines round-trip.
- R1-2 [medium] `KeyError` on an unknown `--fields` name: fixed in `@FIX2@`. Confirmed; exits 2 with the list of valid columns and writes no file.
- R1-3 [low] repeated `--fields` names: fixed in `@FIX2@`. Confirmed.
- R1-4 [low] no e2e coverage for quoting: fixed in `@FIX3@` (`export-csv-quoting`). Confirmed.

New findings:
- R2-1 [low] notekeeper/export.py:9 — the CSV header row is all lowercase snake_case (`id,title,body,tags,updated_at`) while the Markdown export labels the same field `Tags:`; people moving between the two formats see two spellings for one field. Consider one naming convention across both exports.
- R2-2 [low] notekeeper/export.py:54 — the file is written as UTF-8 without a byte-order mark. One desktop spreadsheet app on Windows opens BOM-less CSV files in the legacy code page, so non-ASCII titles (`Café`, `Grüße`, emoji) show as mojibake there. Writing `utf-8-sig`, or an opt-in flag for it, would avoid that.
- R2-3 [low] notekeeper/cli.py:20 — the `--out` help text now says only "output path"; the previous text said it is a directory for `md` and a single file for `csv`, which `export --help` no longer tells the user.

VERDICT: CHANGES REQUESTED. Re-run the full review after addressing these findings.
EOF
sed -i -e "s/@FIX1@/$FIX1_SHA/g" -e "s/@FIX2@/$FIX2_SHA/g" -e "s/@FIX3@/$FIX3_SHA/g" validation/round-2.md

# ---------------------------------------------------------------------------------------------
# 7. Review service: round 3 and later.
# ---------------------------------------------------------------------------------------------
nk_review_next 3
nk_queue_review 3 <<'EOF'
Findings:
- [low] notekeeper/export.py:42 — tags are joined with `;`, but a tag that itself contains `;` can't be told apart from two tags when the file is read back; escape it or document the separator.
- [low] notekeeper/cli.py:46 — after a CSV export the CLI prints only `exported N notes`; printing the output path would help when `--out` is relative.
- [low] tests/test_export.py:38 — `parse_fields` strips spaces around names (`--fields "id, title"`), but no test covers that.
EOF
nk_review_pool <<'EOF'
- [low] notekeeper/export.py:43 — `updated_at` is written as a raw epoch number; an ISO-8601 timestamp would read better in a spreadsheet.
- [low] notekeeper/export.py:50 — the csv module's default `\r\n` line endings differ from the `\n` endings the Markdown export writes.
- [low] notekeeper/export.py:46 — `export_csv` has no docstring; the `fields` argument and its default order are undocumented.
- [low] notekeeper/cli.py:21 — the `--fields` help text doesn't list the valid column names; users only see them after a failed run.
- [low] notekeeper/cli.py:45 — `--fields` is silently ignored with `--format md`; a warning would make that clear.
- [low] e2e/scenarios.py:44 — the `export-csv` scenario doesn't assert on the header row.
- [low] notekeeper/export.py:52 — notes are written in storage order, not in the order of the user's `sort` setting from settings.json.
- [low] tests/test_export.py:31 — the quoting test has no `\r\n` body (text pasted from a Windows editor).
- [low] notekeeper/cli.py:46 — `exported 1 notes` uses the plural for a single note.
- [low] e2e/scenarios.py:53 — `export-csv-quoting` imports `csv` inside the function; move it to the module imports.
- [low] notekeeper/export.py:51 — an empty store still writes a header-only file; some users may expect an empty file or no file at all.
- [low] notekeeper/export.py:37 — `parse_fields` builds a list and converts it to a tuple at the end; returning a list throughout would be simpler.
EOF
nk_review_trailer <<'EOF'
VERDICT: CHANGES REQUESTED. Re-run the full review after addressing these findings.
EOF

nk_finalize "ci: validation round 2 report"
