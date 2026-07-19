# Processing review notes (Sub-task 10)

## Flow

1. Meeting is **Transcribed** (08).
2. User runs **Process with AI** (09) → summary + proposed todos → status **Ready for review**.
3. Review sheet opens (auto after process success, or **Review** on the meetings list).
4. User edits/deletes todo candidates.
5. **Accept remaining** → merge into global `index/todos.json`, clear proposed, status **Completed**.
6. **Discard** → clear proposed, status back to **Transcribed** (can re-process).

## Files

| Artifact | Path |
|----------|------|
| Summary | `meetings/<id>/summary.md` |
| Proposed todos | `meetings/<id>/todos.json` |
| Global todos | `index/todos.json` |

## Manual test

1. Process a transcribed meeting with a local CLI (or mock path in tests).
2. Review sheet shows summary + todos.
3. Delete one todo; edit another title; **Accept remaining**.
4. Todos tab shows accepted items; meeting status **Completed**.
5. Open **Review again** on a completed meeting (loads empty proposed if already accepted).
