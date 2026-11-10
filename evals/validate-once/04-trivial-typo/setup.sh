#!/bin/bash
set -e
. "$(dirname "$0")/../_shared/notekeeper.sh"
nk_base
nk_git branch -M main

# sync --help gets a full description (with the typo the user reports).
python3 - <<'PY'
path = "notekeeper/cli.py"
src = open(path).read()
old = '    s = sub.add_parser("sync", help="sync with a remote snapshot")\n'
new = '''    s = sub.add_parser(
        "sync",
        help="sync with a remote snapshot",
        description="Sync with a remote snapshot and recieve changes made on other devices. "
        "Newer edits win; on a tie the local copy is kept.",
    )
'''
assert src.count(old) == 1, "unexpected cli.py"
open(path, "w").write(src.replace(old, new))
PY
nk_commit "cli: describe sync and how conflicts are resolved in sync --help"

# Snapshot test for sync --help.
mkdir -p tests/snapshots
cat > tests/test_help.py <<'EOF'
"""Snapshot test for `notekeeper sync --help`.

The expected output is in tests/snapshots/sync_help.txt. Width and colour are pinned so the
result doesn't depend on the terminal that runs the tests.
"""
import contextlib
import io
import os
import unittest
from unittest import mock

from notekeeper import cli

SNAPSHOT = os.path.join(os.path.dirname(__file__), "snapshots", "sync_help.txt")
PLAIN_ENV = {"COLUMNS": "80", "NO_COLOR": "1", "PYTHON_COLORS": "0"}


def render_help(*argv):
    out = io.StringIO()
    with mock.patch.dict(os.environ, PLAIN_ENV), contextlib.redirect_stdout(out):
        try:
            cli.main([*argv, "--help"])
        except SystemExit:
            pass
    return out.getvalue()


class HelpSnapshotTest(unittest.TestCase):
    maxDiff = None

    def test_sync_help_matches_snapshot(self):
        with open(SNAPSHOT, encoding="utf-8") as f:
            expected = f.read()
        self.assertEqual(render_help("sync"), expected, "sync --help output differs from tests/snapshots/sync_help.txt")
EOF
NK_IN_CHECK=1 PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
from tests.test_help import SNAPSHOT, render_help

text = render_help("sync")
assert "recieve changes" in text and text.startswith("usage: notekeeper sync"), text
with open(SNAPSHOT, "w", encoding="utf-8") as f:
    f.write(text)
PY
NK_IN_CHECK=1 PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -q tests.test_help 2>/dev/null \
  || { echo "setup: help snapshot test does not pass as set up" >&2; exit 1; }
nk_commit "tests: snapshot test for sync --help"

# Release prep.
printf '__version__ = "0.4.0"\n' > notekeeper/__init__.py
cat > CHANGELOG.md <<'EOF'
# Changelog

## 0.4.0 (unreleased)

- `sync --help` now says what sync does and how conflicts are resolved.
- Snapshot test for the `sync --help` output (`tests/test_help.py`).

## 0.3.0

- Markdown and CSV export.
- Two-way sync with a remote snapshot.
EOF

# Line numbers for the review service's findings (used only if a review round is run).
L_DATA=$(grep -n 'p.add_argument("--data"' notekeeper/cli.py | cut -d: -f1)
L_TAG=$(grep -n 'a.add_argument("--tag"' notekeeper/cli.py | cut -d: -f1)
L_LS=$(grep -n 'sub.add_parser("ls"' notekeeper/cli.py | cut -d: -f1)
L_OUT=$(grep -n 'e.add_argument("--out"' notekeeper/cli.py | cut -d: -f1)
L_REMOTE=$(grep -n 's.add_argument("remote"' notekeeper/cli.py | cut -d: -f1)
L_SYNCED=$(grep -n 'print(f"synced' notekeeper/cli.py | cut -d: -f1)
L_PLAIN=$(grep -n '^PLAIN_ENV' tests/test_help.py | cut -d: -f1)
L_EXIT=$(grep -n 'except SystemExit' tests/test_help.py | cut -d: -f1)

nk_review_pool <<EOF
- [low] notekeeper/cli.py:${L_OUT} \`export --out\` help doesn't say that the Markdown output directory is created when it doesn't exist.
- [low] tests/test_help.py: only \`sync --help\` has a snapshot; \`add\`, \`ls\` and \`export\` help can change without a test noticing.
- [low] notekeeper/cli.py:${L_LS} \`ls\` help says "list notes" but not what each line shows (id, then title).
- [low] notekeeper/cli.py:${L_DATA} \`--data\` help ("notes file") doesn't mention the NOTEKEEPER_DATA environment variable that sets the default.
- [low] README.md: the sync example doesn't say that the remote snapshot file is created when it doesn't exist yet.
- [low] CHANGELOG.md: the 0.4.0 entry doesn't mention the reworded sync help text.
- [low] tests/test_help.py:${L_PLAIN} the snapshot is rendered only at 80 columns; a narrow-terminal snapshot would catch wrapping changes.
- [low] notekeeper/cli.py:${L_SYNCED} "synced 1 notes": pluralise the message.
- [medium] notekeeper/cli.py:${L_TAG} \`--tag ""\` stores an empty tag; reject empty tags when parsing.
- [low] notekeeper/__init__.py:1 \`__version__\` is set but there is no \`notekeeper --version\`; add one before tagging.
- [low] notekeeper/cli.py:${L_REMOTE} \`remote\` help ("remote snapshot file") doesn't say the file is JSON.
- [low] tests/test_help.py:${L_EXIT} catching SystemExit hides a non-zero exit code; assert that \`--help\` exits with 0.
EOF

rmdir validation 2>/dev/null || true  # no validation reports for this release yet
nk_finalize "release: 0.4.0 changelog and version"
