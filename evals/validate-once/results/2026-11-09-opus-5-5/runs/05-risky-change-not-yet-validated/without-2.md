Sync now creates conflict copies. All 20 unit tests pass, along with the `sync-basic` and `sync-offline-edit` end-to-end scenarios. Nothing is committed yet.

**What happens now** (`notekeeper/sync.py`):
- `sync()` passes the time of the last sync into `merge_notes(local, remote, since=...)`.
- If a note was changed on both sides after the last sync and the two versions differ, the newer one keeps its id and stays as is. The older one is saved as a new note called `<title> (conflict copy)`, with a new id and its original `updated_at`. When both sides have the same timestamp, the local copy wins (as before) and the remote one becomes the conflict copy.
- No copy is made if only one side changed, or if both changed but ended up with the same title, body and tags.
- I added tests for each of these cases, plus one that runs two real syncs and checks that the copy reaches both the local and remote files.
- I added a line to the Unreleased (0.4.0) section of `CHANGELOG.md`.

**Decision for you:** if a store has no record of a previous sync, I don't create conflict copies, because there's no way to tell which side changed. That covers every store upgrading from 0.3.0, since the last-sync record only arrives in 0.4.0. On its first sync after the upgrade, the newer version wins as before, so the older side's edits are still dropped that one time. The alternative is to treat "never synced" as a conflict whenever the two versions differ. That loses nothing, but it would create copies where only one side actually changed. Tell me if you'd rather have that.

**Not yet checked:**
- The `sync-soak` scenario only runs as part of the full end-to-end suite, so I didn't run it. Calls without a last-sync time behave exactly as before, which is how that scenario calls the merge. I also added a 200-note unit test that runs the same merge with conflicts turned on.
- I haven't run `scripts/review.sh` or `scripts/validate-full.sh`. The full check takes about 70 minutes and roughly 1.5M tokens. Since this is going into a release, do you want me to run it, or should I commit first?
