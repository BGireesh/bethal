# Global todos notes (Sub-task 11)

## UI

- Segmented filter: **Open** / **Done** / **All**
- Checkbox toggles complete (clears reminder when completed)
- Provenance link: `From: <meeting> · <when>` → opens Review when meeting is reviewable
- Remind menu: In 1 hour / Tomorrow 9:00 AM / In 3 days; Clear reminder

## Storage

- Global list: `index/todos.json` (accepted only)
- `reminderAt` persisted on the todo item
- Notification id: `bethal.todo.<todoID>`

## Manual test

1. Accept todos from a processed meeting (Review → Accept).
2. Todos tab → see Open list with provenance.
3. Mark one complete → appears under Done.
4. Set reminder on an open todo → label shows; Clear reminder.
5. Click provenance → Meetings + Review sheet when status is Ready for review / Completed.
