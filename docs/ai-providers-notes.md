# AI providers notes (Sub-task 09)

## Decision

| Topic | Choice | Rationale |
|-------|--------|-----------|
| Discovery | Augmented PATH: Homebrew, `~/.local/bin`, `~/.grok/bin`, cargo/npm bins, then process PATH | GUI apps get a minimal PATH (`/usr/bin:/bin`); shell PATH is not used |
| Invocation | Non-interactive flags + prompt arg (`-p` / `codex exec`) | Scriptable; no TUI |
| Output | Strict JSON `{ summaryMarkdown, todos[] }` | Parseable in unit tests and production |
| Runner | `ProcessRunner` protocol + `FoundationProcessRunner` | 100% coverage via mock |
| Selection | Settings default + **Ask every time** | Matches product requirements |

## Settings

- **Default tool** picker (None / Claude / Codex / Grok)
- **Ask every time** toggle
- **Refresh local tools** lists Available / Missing with install hints

## Post-call chooser

- Meetings with status ≥ transcribed: **Process with AI**
- Policy: if default available and not ask-every-time → run immediately; else sheet list; if none → empty how-to

## Manual test

1. Settings → Refresh local tools (expect at least one Available if CLIs installed).
2. Set default + Ask every time on/off and confirm label.
3. Transcribe a meeting, then **Process with AI**.
4. With ask-every-time: pick a tool; progress completes → status **Ready for review**.
5. Confirm `summary.md` + `todos.json` under the meeting folder.
6. With all tools missing from PATH: empty state + install copy.

## Limits

- CLI argument quirks may need per-tool tuning as versions change.
- Full review UI (edit/drop todos, accept to global list) is **sub-task 10**.
- Bethal never uploads meeting data; CLIs run under the user’s account/policies.
