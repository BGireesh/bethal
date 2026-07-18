# Bethal

**Privacy-first, on-device meeting capture and intelligence for macOS.**

Bethal records meetings (audio or audio+video) on your Mac, stores everything under a directory you choose, and processes calls using **local tools you already have** (Claude CLI, Codex, Grok, etc.) — not a third-party cloud that mines your meeting data.

| | |
|---|---|
| **Bundle ID** | `us.gireesh.bethal` |
| **Platform** | macOS 14+ |
| **Stack** | SwiftUI · Swift · Xcode |
| **Plan** | [`project-plan.md`](./project-plan.md) (source of truth) |

## Status

Sub-tasks **01–02** done. Sub-task **03** adds first-launch onboarding (privacy, working directory, optional default AI). Recording and full home shell land next — tracked in `project-plan.md`.

## Requirements

- macOS 14.0 or later
- Xcode 16+ (tested with Xcode 26)
- Apple Silicon or Intel Mac (CI/scripts default to `arm64`)

## Open & run

```bash
open Bethal.xcodeproj
```

In Xcode: select the **Bethal** scheme → **My Mac** → Run (`⌘R`).

Or from the terminal:

```bash
xcodebuild \
  -project Bethal.xcodeproj \
  -scheme Bethal \
  -destination 'platform=macOS,arch=arm64' \
  build
```

The app opens a placeholder Home window with the product name and bundle id.

## Tests

```bash
# Unit tests
./Scripts/test.sh

# Unit tests + Domain coverage gate (100%)
./Scripts/coverage.sh
```

Or in Xcode: **Product → Test** (`⌘U`). Coverage is enabled on the shared **Bethal** scheme.

### Coverage policy

- **Domain/** (pure logic): **100%** line coverage required (`Scripts/coverage.sh` enforces this).
- **App UI**: covered via view models/services as they appear; pure `View` bodies are not the coverage target.
- Every feature PR must ship unit tests for new/changed testable code.

## Project layout

```text
Bethal/
  App/           # @main, windows, SwiftUI views
  Domain/        # Models, path layout, pure helpers
  Services/
    Storage/     # WorkingDirectoryStore, JSON, schema migration
  Resources/     # Assets, entitlements
BethalTests/     # Swift Testing unit tests
Scripts/         # test.sh, coverage.sh
project-plan.md  # Requirements + PR-sized sub-tasks
```

## Working directory layout

Created by `WorkingDirectoryStore.initialize()` under a user-chosen root (onboarding in sub-task 03):

```text
<WorkingDirectory>/
  .bethal/schema.json
  .bethal/settings.json
  meetings/<id>/meta.json
  meetings/<id>/transcript.json
  meetings/<id>/summary.md
  meetings/<id>/todos.json
  index/meetings.json
  index/todos.json
  exports/
```

## Development workflow

1. Pick the next open sub-task in `project-plan.md`.
2. Branch: `feat/<nn>-short-name`.
3. Implement + unit tests (100% on Domain/Services touched).
4. Open a PR with **Manual test steps**.
5. After merge to `main`, mark the sub-task `[x]` in `project-plan.md`.

## Privacy

Bethal is designed so recording and storage stay on your machine. AI steps use **your** local CLI subscriptions. The app does not operate a Bethal cloud for meeting content.

## License

Private — all rights reserved unless otherwise noted.
