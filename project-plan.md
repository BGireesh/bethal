# Bethal — Project Plan (Source of Truth)

**App name:** Bethal  
**Bundle / package ID:** `us.gireesh.bethal`  
**Platform:** macOS native (Swift / SwiftUI)  
**Repo:** `BGireesh/bethal` (this folder)  
**Status legend:** `[ ]` pending · `[~]` in progress · `[x]` done (merged to `main`)

> **How we work**  
> 1. Each **sub-task** = one feature branch + one PR.  
> 2. After merge to `main`, mark the sub-task `[x]` in this file.  
> 3. This document is the memory and backlog. Update it when scope changes.  
> 4. Unit tests ship with every PR. **Target: 100% coverage of code we touch.**  
> 5. Manual test checklist is required in every PR description so you can verify on device before merge.

---

## 1. Vision

Bethal is a **privacy-first, fully on-device** meeting capture and intelligence app for macOS.

You attend many vendor/partner meetings. Existing tools either:

- Require Google/Microsoft workspace access and join calls as a bot, or  
- Ship audio to the cloud, mine data, and lock you into their AI stack.

Bethal does the opposite:

- Runs **natively on your Mac** for performance and privacy.  
- Records **audio-only or audio+video** locally.  
- Stores everything under a **user-chosen working directory**, properly indexed.  
- Processes calls using **tools already on your machine** (Claude CLI, Codex, Grok, etc.) — same spirit as [Conductor](https://conductor.build): use **your** subscriptions and local agents, not a third-party cloud that owns your meeting data.  
- Produces **transcript + summary + actionable todos**, with a **global todo list** across all meetings.

**Core promise (shown on first launch):**  
*Everything happens on your device. Recordings, transcripts, and todos stay in your working directory. AI processing uses tools you already configure locally.*

---

## 2. Product requirements

### 2.1 Onboarding (first launch)

| Requirement | Detail |
|-------------|--------|
| Privacy explainer | Full-screen onboarding: on-device processing, no cloud mining by Bethal, data lives in working directory. |
| Working directory | User must pick a folder (e.g. `~/Documents/Bethal`). All recordings, indexes, transcripts, todos live under it. |
| Permissions | Request only what’s needed, with clear copy: Microphone, Screen Recording / system audio capture as required by macOS, Calendar (optional, for auto-detect), Notifications (reminders / 1-click start). |
| Default AI provider | Optional during onboarding: pick default processor (Claude / ChatGPT-Codex / Grok / other configured). Can change later in Settings. |
| Completion | Mark onboarding complete; land on Home (Meetings + Todos). |

### 2.2 Meeting capture

| Requirement | Detail |
|-------------|--------|
| Explicit start | Before/during any meeting, user can **Start recording** (1 click). |
| Auto-detect + remind | Integrate with **macOS Calendar** (EventKit). When a meeting is about to start (or is active), show a **notification / in-app banner** with **1-click Start recording**. Never auto-start recording without explicit user action (privacy + trust). |
| Modes | **Audio-only** or **Audio + video**. User chooses (or default in Settings). Video includes system/display capture as designed in tech spike. |
| During recording | Clear UI: elapsed time, mode, pause/stop, source indicators. |
| Stop | On Stop (or meeting end detection if available), finalize media files into working directory and open **post-call processing** flow. |

### 2.3 Storage & indexing (working directory)

All data under the chosen root, e.g.:

```text
<WorkingDirectory>/
  .bethal/                    # app metadata, schema version, settings (no secrets in plain if avoidable)
  meetings/
    <meeting-id>/
      meta.json               # title, start/end, calendar event id, mode, paths
      audio.* / video.*       # recorded media
      transcript.json         # segments with timestamps
      summary.md              # AI summary
      todos.json              # proposed todos for this call (pre-accept)
  index/
    meetings.json             # searchable index of all meetings
    todos.json                # global todo store (or SQLite — see architecture)
  exports/                    # optional user exports
```

**Indexing:** Every meeting and todo is queryable (title, date, participants if known, transcript full-text later). Storage layout must survive app updates via schema versioning.

### 2.4 Post-call processing

When a call finishes:

1. App prompts: *“Your system has Claude / ChatGPT (Codex) / Grok / other configured. Which should process this call?”*  
2. User selects provider (or uses **default** if configured and “always use default” is on).  
3. Pipeline runs **locally** (media never uploaded by Bethal itself):  
   - **Transcribe** (local speech-to-text; see architecture).  
   - **Summarize** via selected agent/CLI.  
   - **Generate todo candidates** via selected agent/CLI.  
4. **Review UI:** User reviews transcript, summary, and proposed todos.  
5. User **removes** unwanted todos; **saves** only accepted ones into the **global** todo list.  
6. Meeting marked `processed`; available in library for re-watch/re-listen + transcript.

### 2.5 Global todos

| Requirement | Detail |
|-------------|--------|
| Global list | Todos from all meetings in one place (day/week/all filters). |
| Complete | Mark done / incomplete. |
| Reminders | Optional reminder (local notification / EventKit reminder — decide in implementation PR). |
| Provenance | Default view + hover: *“From: &lt;Meeting title&gt; · &lt;date&gt;”* with **hyperlink**. |
| Deep link | Clicking meeting link opens **Meeting Review**: player (A/V) + transcript (synced where possible) + summary + related todos. |

### 2.6 Meeting review

- Play/listen to stored media.  
- Transcript panel (searchable, timestamp seek on click when timestamps exist).  
- Summary and linked todos.  
- Re-run processing with a different provider (optional stretch).

### 2.7 Settings

- Working directory (change path with migration warning).  
- Default AI provider + “ask every time” vs “always use default”.  
- Default capture mode (audio / A+V).  
- Calendar auto-detect window (e.g. remind 2 min before).  
- Detected local tools (Claude CLI path, Codex, Grok, etc.) with refresh.  
- Permissions status.

### 2.8 Non-goals (v1)

- Joining meetings as a bot participant.  
- Bethal-operated cloud transcription/storage.  
- Google/Microsoft workspace OAuth as a hard dependency.  
- Multi-user sync / team workspace.  
- iOS/iPad companion (future).

---

## 3. Design principles

1. **Privacy by default** — local files, explicit recording consent every time (or clear 1-click after reminder).  
2. **Native performance** — Swift, AVFoundation, efficient indexing; no Electron.  
3. **User-owned AI** — orchestrate local CLIs/subscriptions; Bethal is the meeting shell, not the model host.  
4. **Review before commit** — AI todos are proposals until the user accepts.  
5. **Testable architecture** — pure domain logic, protocols for calendar/recording/AI/fs so unit tests hit 100% of testable surface without hardware.  
6. **PR-sized increments** — each sub-task merges independently and is manually testable.

---

## 4. Technical architecture (proposed)

### 4.1 Stack

| Layer | Choice |
|-------|--------|
| UI | SwiftUI (macOS 14+ target; confirm exact minimum in scaffold PR) |
| App lifecycle | SwiftUI `App` + optional AppKit bridges for status item / permissions |
| Recording | AVFoundation (mic); screen/system audio via ScreenCaptureKit where needed |
| Calendar | EventKit |
| Notifications | UserNotifications |
| Persistence | File-based working directory + SQLite (or JSON index) for todos/meetings metadata |
| Transcription | Local first: Apple Speech and/or embedded Whisper (e.g. whisper.cpp / SpeechAnalyzer) — spike in Sub-task 05 |
| AI orchestration | Process wrappers: `claude`, `codex`, `grok` CLI (and extensible registry) with prompt templates |
| Package ID | `us.gireesh.bethal` |
| Tests | Swift Testing and/or XCTest; protocol mocks for 100% coverage of domain/services |

### 4.2 Module boundaries (packages / folders)

```text
Bethal/
  App/                 # @main, onboarding gate, DI composition
  Features/
    Onboarding/
    Home/
    Recording/
    Processing/
    Todos/
    MeetingReview/
    Settings/
  Domain/              # models, pure logic (high unit-test density)
  Services/
    Storage/
    Calendar/
    Recording/
    Transcription/
    AIProviders/
    Notifications/
  DesignSystem/        # shared UI components
  Resources/
BethalTests/           # unit tests mirroring modules
```

### 4.3 AI provider abstraction

```text
protocol AIProvider {
  var id: String { get }
  var displayName: String { get }
  func isAvailable() async -> Bool
  func process(request: MeetingProcessRequest) async throws -> MeetingProcessResult
}
```

Concrete adapters:

- `ClaudeCLIProvider`  
- `CodexCLIProvider`  
- `GrokCLIProvider`  
- `CustomShellProvider` (user-defined command template)

Discovery: check PATH / known install locations / user overrides in Settings.

**Important:** Bethal never sends meeting data to Bethal servers. Providers run as local processes; user is responsible for what those CLIs do under their own subscriptions/policies.

### 4.4 Processing pipeline

```text
Stop Recording
  → Persist media + meta (status: captured)
  → Prompt provider (or default)
  → Transcribe → transcript.json (status: transcribed)
  → AI summarize + extract todos (status: processed_pending_review)
  → Review UI (edit/drop todos)
  → Accept → merge into global todos (status: completed)
```

Idempotent steps; crash-safe status on `meta.json`.

### 4.5 Testing strategy (100% coverage of touched code)

| Layer | Approach |
|-------|----------|
| Domain models / reducers / index / todo merge | Pure unit tests, no mocks needed |
| Storage paths, schema migrate, index CRUD | Temp directories in unit tests |
| AI provider parsing / prompt builders | Fixture stdin/stdout, fake `ProcessRunning` protocol |
| Calendar mapping | Mock `CalendarClient` |
| Recording session state machine | Mock `CaptureEngine` |
| UI | Prefer testable view models; snapshot optional later |

**CI:** `xcodebuild test` on macOS runner (or local script until CI exists). Coverage report per PR; fail under threshold for new code if tooling allows.

**Manual:** Every PR includes a short “How to verify” section.

### 4.6 Permissions matrix

| Permission | Why |
|------------|-----|
| Microphone | Audio capture |
| Screen Recording | System audio / meeting window video (ScreenCaptureKit) |
| Calendar | Meeting auto-detect & titles |
| Notifications | Pre-meeting 1-click start, todo reminders |

---

## 5. Sub-tasks (PR plan)

Each sub-task is one branch: `feat/<id>-short-name` → PR → you manual test → merge → mark `[x]` here.

---

### Sub-task 01 — Project scaffold & quality bar  
**Status:** `[x]` done (merged PR #1)  
**Branch:** `feat/01-scaffold`  
**Goal:** Runnable empty macOS app with identity, structure, test target, and docs link.

**Deliverables:**

- Xcode project for `us.gireesh.bethal` (macOS 14+, SwiftUI)  
- App shows placeholder Home window (“Bethal”)  
- Folder structure: `Bethal/App`, `Bethal/Domain`, `Bethal/Resources`, `BethalTests`, `Scripts`  
- Unit test target (Swift Testing) + `Scripts/test.sh` + `Scripts/coverage.sh` (Domain 100% gate)  
- README: build/run instructions  
- Entitlements: app sandbox **off** for v1 CLI/working-directory ergonomics (see §8)  

**Manual test:** Build & run; app launches; `./Scripts/test.sh` and `./Scripts/coverage.sh` pass.

**Tests:** `AppIdentity` + `ProjectLayout` (100% Domain coverage).

---

### Sub-task 02 — Domain models & working-directory storage  
**Status:** `[x]` done (merged PR #2)  
**Branch:** `feat/02-storage`  
**Goal:** Canonical models and file layout under user working directory.

**Deliverables:**

- Models: `Meeting`, `Transcript`, `TranscriptSegment`, `TodoItem`, `AppSettings`, `MeetingStatus`, `CaptureMode`, `SchemaManifest`  
- `WorkingDirectoryStore`: create layout, read/write meta, index meetings/todos, transcript/summary/proposed todos  
- Schema version + `SchemaMigrator` (v1 baseline + upgrade path)  
- `FileSystemClient` abstraction + `FoundationFileSystem`  
- No UI changes (storage only)  

**Manual test:** `./Scripts/test.sh` and `./Scripts/coverage.sh`; optional quick unit path is covered by temp-disk test.

**Tests:** 100% Domain + Services/Storage (create, load, migrate, corrupt-file, IO failures).

---

### Sub-task 03 — Onboarding & privacy flow  
**Status:** `[x]` done (merged PR #3)  
**Branch:** `feat/03-onboarding`  
**Goal:** First-launch onboarding with privacy story + working directory selection.

**Deliverables:**

- Multi-step onboarding UI (privacy → directory picker → optional default provider → finish)  
- Persist `hasCompletedOnboarding` + working directory security-scoped bookmark via `AppSessionStore`  
- `OnboardingCompleter` initializes working directory + settings  
- Gate main app via `RootView` until complete  
- “Change later in Settings” copy  

**Manual test:** Fresh launch → complete onboarding → relaunch skips to Home; directory has `.bethal/`.

**Tests:** Flow state, session store, bookmarks, completer, view model (100% Domain/Services + OnboardingViewModel).

---

### Sub-task 04 — Home shell, navigation, settings shell  
**Status:** `[x]` done (merged PR #4)  
**Branch:** `feat/04-shell`  
**Goal:** App chrome: Meetings list, Todos list placeholders, Settings.

**Deliverables:**

- `NavigationSplitView` sidebar: Meetings | Todos | Settings  
- Empty states for meetings/todos  
- Settings: working directory path, Open in Finder, AI/capture/calendar summaries  
- Design tokens (`DesignSpacing`, `DesignTypographyRole`)  
- `HomeShellViewModel` + `SettingsViewModel`  

**Manual test:** Navigate all sections; open working directory in Finder; empty states when no data.

**Tests:** Navigation, empty states, settings VM, workspace opener, home shell VM (100% Domain/Services + VMs).

---

### Sub-task 05 — Capture permissions & recording spike (tech decision)  
**Status:** `[x]` done (merged PR #5)  
**Branch:** `feat/05-recording-spike`  
**Goal:** Prove mic + optional screen/system audio capture; document API choices.

**Deliverables:**

- Permission helpers (`PermissionChecking`, mic + screen)  
- `RecordingSessionState` machine + `RecordingSessionCoordinator`  
- `AVAudioCaptureEngine` (mic → `audio.m4a`); A/V defers full ScreenCaptureKit to 06  
- Sidebar **Record** spike UI  
- `docs/recording-notes.md`  

**Manual test:** Grant mic; record ~10s; meeting + `audio.m4a` under working directory; Refresh Meetings list.

**Tests:** State machine, coordinator, mock engine, spike VM (100% Domain/Services; AV/TCC wrappers excluded).

---

### Sub-task 06 — Production recording UI & session lifecycle  
**Status:** `[~]` in progress (PR open)  
**Branch:** `feat/06-recording-ui`  
**Goal:** Explicit start/stop recording with audio vs A/V modes.

**Deliverables:**

- Production `RecordingSessionView` + `RecordingViewModel` (title, mode, timer, start/stop/cancel)  
- Toolbar + empty-state **Start recording** entry points  
- On stop: media + `meta.json` with `captured`; cancel deletes in-progress meeting  
- Meetings list presentation (status / mode / when labels)  

**Manual test:** Record audio (and A/V mode); stop → meeting in list; cancel discards session.

**Tests:** Cancel path, presentation helpers, production VM (100% Domain/Services).

---

### Sub-task 07 — Calendar integration & pre-meeting 1-click remind  
**Status:** `[ ]`  
**Branch:** `feat/07-calendar`  
**Goal:** Detect upcoming calendar events; notify with 1-click start (never auto-record).

**Deliverables:**

- EventKit calendar client  
- Poll or event-based “meeting starting soon”  
- Notification + in-app banner → starts recording flow (optionally prefill title from event)  
- Settings: enable/disable, minutes-before  

**Manual test:** Create calendar event soon; receive reminder; 1-click opens recording with title.

**Tests:** Event filtering, scheduling math, mapping to meeting meta (mocked EventKit).

---

### Sub-task 08 — Local transcription pipeline  
**Status:** `[ ]`  
**Branch:** `feat/08-transcription`  
**Goal:** Produce timestamped transcript from recorded audio (video: extract audio track).

**Deliverables:**

- `TranscriptionService` protocol + concrete local implementation (chosen in 05/08)  
- Write `transcript.json`  
- Progress UI  
- Failure/retry  

**Manual test:** Record short speech; transcript segments appear with timestamps.

**Tests:** Audio extract helpers, JSON codec, service orchestration with fake engine.

---

### Sub-task 09 — AI provider registry & post-call chooser  
**Status:** `[ ]`  
**Branch:** `feat/09-ai-providers`  
**Goal:** Discover local CLIs; choose provider per call or default.

**Deliverables:**

- Provider registry + availability checks  
- Settings: default provider, ask-every-time toggle  
- Post-call sheet: list available providers  
- Process runner abstraction (testable)  
- Prompt templates for summary + todos (fixtures)  

**Manual test:** With at least one CLI installed, see it listed; with none, empty state + how-to.

**Tests:** Discovery parsing, prompt building, mock process I/O for summary/todo JSON parsing (100%).

---

### Sub-task 10 — Full processing pipeline + review before save  
**Status:** `[ ]`  
**Branch:** `feat/10-processing-review`  
**Goal:** Transcribe → summarize → propose todos → user review → accept/reject.

**Deliverables:**

- Pipeline orchestrator with persisted status  
- Review screen: summary, transcript peek, editable todo candidates (delete, edit text)  
- Accept → global todos + mark meeting processed  
- Discard / re-process entry points  

**Manual test:** End-to-end one meeting with mock or real CLI; reject one todo; accept rest; global list updates.

**Tests:** Orchestrator state machine, merge rules, candidate editing (100% domain).

---

### Sub-task 11 — Global todos UI (complete, remind, provenance links)  
**Status:** `[ ]`  
**Branch:** `feat/11-todos`  
**Goal:** Beautiful global todo list with meeting provenance.

**Deliverables:**

- List: incomplete / completed filters  
- Mark complete  
- Reminder setup (local notification)  
- Hover/detail: source meeting title + date  
- Hyperlink → Meeting Review route (stub ok if 12 lands next)  

**Manual test:** Todos from multiple meetings; complete one; set reminder; open meeting link.

**Tests:** Todo store CRUD, filter, reminder scheduling protocol mocks.

---

### Sub-task 12 — Meeting review player + synced transcript  
**Status:** `[ ]`  
**Branch:** `feat/12-meeting-review`  
**Goal:** Watch/listen + transcript bottom panel + seek.

**Deliverables:**

- AV player for audio/video files in meeting folder  
- Transcript list; tap segment seeks player  
- Optional auto-highlight current segment by time  
- Summary + related todos sidebar/section  

**Manual test:** Play meeting; click transcript seeks; video meetings show video.

**Tests:** Time↔segment mapping pure functions 100%; player VM with mock player.

---

### Sub-task 13 — Polish: menu bar, reliability, export, edge cases  
**Status:** `[ ]`  
**Branch:** `feat/13-polish`  
**Goal:** Daily-driver hardening.

**Deliverables:**

- Menu bar extra: quick Start / Stop / upcoming meeting  
- Crash-safe resume of interrupted processing  
- Export meeting folder / markdown summary  
- Empty/error copy polish  
- Performance pass on large transcripts  

**Manual test:** Day-in-the-life path: onboarding already done → calendar remind → record → process → todos → review.

**Tests:** Resume/migration edge cases; export builders.

---

### Sub-task 14 — CI, coverage gate, release packaging  
**Status:** `[ ]`  
**Branch:** `feat/14-ci-release`  
**Goal:** Automated test gate + notarization-ready archive notes.

**Deliverables:**

- GitHub Actions macOS workflow: build + test  
- Coverage reporting (aim 100% on Domain/Services)  
- `docs/release.md`: signing, notarization checklist  
- Versioning scheme  

**Manual test:** CI green on PR; local archive succeeds if certificates available.

**Tests:** N/A beyond ensuring suite is CI-stable.

---

## 6. Suggested implementation order

```text
01 Scaffold
 → 02 Storage
 → 03 Onboarding
 → 04 Shell
 → 05 Recording spike
 → 06 Recording UI
 → 07 Calendar remind
 → 08 Transcription
 → 09 AI providers
 → 10 Processing + review
 → 11 Todos
 → 12 Meeting review
 → 13 Polish
 → 14 CI / release
```

Dependencies are mostly linear; **07** can parallelize with **08** after **06** if desired. **11** needs **10** for real data but can use fixtures.

---

## 7. Definition of done (per PR)

- [ ] Implements only this sub-task’s scope  
- [ ] Unit tests for new/changed logic; **100% coverage of touched testable code**  
- [ ] App builds; automated tests pass  
- [ ] PR description includes **Manual test steps**  
- [ ] No secrets committed  
- [ ] `project-plan.md` status updated only after merge (or in a follow-up chore commit on main)  
- [ ] You have manually verified and approved merge  

---

## 8. Risks & open decisions

| Risk / decision | Notes | Resolve by |
|-----------------|-------|------------|
| System audio capture complexity | macOS TCC + ScreenCaptureKit; loopback differs by OS version | Sub-task 05 |
| Local transcription quality | Apple Speech vs Whisper size/perf tradeoff | Sub-task 05/08 |
| Sandbox vs non-sandbox | CLI invocation and arbitrary working directory may need non-sandbox or broad entitlements for v1 power-user use | Sub-task 01/09 |
| CLI output formats | Claude/Codex/Grok stdout differs; need strict JSON schema in prompts + robust parse | Sub-task 09 |
| Video size on disk | Large meetings; need retention/settings later | Sub-task 13 / future |
| “100% coverage” | UI views hard to cover; enforce 100% on Domain + Services; UI via VMs | All PRs |

**Decision default (unless you override):**

- v1 ships **non-sandboxed** or with carefully chosen entitlements so local CLIs and user-selected directories work like Conductor-style tools.  
- Transcription: prefer **high-quality local** (Whisper or best available on-device) over cloud.  
- Never auto-start recording without a user click (notification counts as invitation, not consent until click).

---

## 9. Success criteria (v1 complete)

1. First launch onboarding explains native/privacy model and locks a working directory.  
2. User can explicitly record audio or A/V meetings to that directory.  
3. Calendar can remind with 1-click start.  
4. After stop, user picks local AI tool; gets transcript, summary, todo proposals.  
5. User curates todos into a global list with meeting hyperlinks.  
6. Meeting review plays media with transcript.  
7. All processing and storage remain on device under the working directory.  
8. Test suite covers domain/services at 100%; each feature landed via reviewed PR.

---

## 10. Changelog of plan updates

| Date | Change |
|------|--------|
| 2026-07-18 | Initial project plan from product requirements; 14 sub-tasks defined. |
| 2026-07-18 | Sub-task 01 marked done after PR #1 merge (scaffold + tests + coverage gate). |
| 2026-07-18 | Sub-task 02 marked done after PR #2 merge (storage layer). |
| 2026-07-18 | Sub-task 03 in progress: onboarding + privacy + working directory. |
| 2026-07-18 | Sub-task 03 marked done after PR #3 merge; sub-task 04 home shell in progress. |
| 2026-07-18 | Sub-task 04 marked done after PR #4 merge; sub-task 05 recording spike in progress. |
| 2026-07-18 | Sub-task 05 marked done after PR #5 merge; sub-task 06 production recording UI in progress. |

---

## 11. Next action

**Sub-tasks 01–05 complete** once 06 merges. Next: **Sub-task 07 — Calendar integration**.
