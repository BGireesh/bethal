# Recording notes (Sub-task 05 spike)

## Decisions

| Topic | Choice | Rationale |
|-------|--------|-----------|
| Default capture mode | **Audio only** | Lower disk use, fewer TCC prompts, sufficient for most vendor calls |
| Microphone API | `AVAudioRecorder` → AAC/`audio.m4a` @ 44.1 kHz mono | Simple, reliable, high quality for speech |
| Video / system audio (planned) | **ScreenCaptureKit** | Modern API for display/window capture + optional app audio |
| A/V in this spike | Mic audio is recorded; full video multiplex **deferred to sub-task 06** | Keep spike small and testable; SCK pipeline is non-trivial |
| Auto-start | **Never** | Explicit Start click only (calendar 1-click later still requires click) |

Constants are also encoded in `RecordingSpikeDecisions` for the app to surface.

## Permissions (TCC)

| Permission | When | Prompt / API |
|------------|------|----------------|
| **Microphone** | Always for recording | System mic dialog via `AVCaptureDevice.requestAccess(for: .audio)` |
| **Screen Recording** | Audio+video mode | `CGRequestScreenCaptureAccess()` / System Settings → Privacy → Screen Recording |

App sandbox is **off** (v1). Mic usage string is set via generated Info.plist key `NSMicrophoneUsageDescription`.

### Expected user flow

1. Open **Record** in the sidebar.
2. Choose **Audio only** (recommended) or **Audio + video (spike)**.
3. **Prepare permissions** (or Start, which prepares first).
4. Grant Microphone (and Screen if A/V).
5. **Start test recording** → speak for a few seconds → **Stop**.
6. Meeting appears under working directory: `meetings/<id>/audio.m4a` + `meta.json` (`status: captured`).

## Working directory layout (after stop)

```text
<WorkingDirectory>/
  meetings/
    <uuid>/
      meta.json      # status=captured, captureMode, audioFileName
      audio.m4a
```

## Limitations of this spike

- No pause/resume.
- No menu-bar quick controls (sub-task 13).
- No system audio loopback in audio-only mode (mic only).
- Audio+video does **not** yet write a video file; reason stored on session as `videoDeferredReason`.
- Production recording UI polish is sub-task 06.

## Recommended production path (post-06)

1. Keep audio-only default.
2. For A/V: ScreenCaptureKit stream → `.mp4` (or audio track extracted for transcription).
3. Always finalize into `WorkingDirectoryStore` with crash-safe status transitions.

## Manual test checklist

- [ ] Mic permission prompt appears once
- [ ] 5–10 s audio-only recording produces `audio.m4a`
- [ ] Meeting listed under **Meetings** after Refresh
- [ ] A/V mode still produces audio and shows deferred-video note
- [ ] Denying mic fails with a clear error (no silent no-op)
