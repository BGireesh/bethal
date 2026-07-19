# Transcription notes (Sub-task 08)

## Decision

| Topic | Choice | Rationale |
|-------|--------|-----------|
| Engine | **Apple Speech** (`SFSpeechRecognizer`) | Built into macOS, no large binary, on-device when `supportsOnDeviceRecognition` |
| Input | Meeting `audio.m4a` preferred; fall back to video container | Matches capture layout from 05/06 |
| Output | `meetings/<id>/transcript.json` | Existing Domain `Transcript` model |
| Status | Meeting → `transcribed` on success; `failed` + `failureReason` on error | Fits processing pipeline |

## Permissions

- **Speech Recognition** TCC via `SFSpeechRecognizer.requestAuthorization`
- Info.plist: `NSSpeechRecognitionUsageDescription`

## UI

- Meetings list: **Transcribe** / **Re-transcribe** / **Retry transcription**
- Sheet shows linear progress + Retry/Done
- Never blocks recording; user-initiated (auto pipeline can hook in later)

## Manual test

1. Record a short spoken clip (Record → Start → speak → Stop).
2. Meetings → select **Transcribe** on the new meeting.
3. Grant Speech Recognition if prompted.
4. Sheet shows progress; Done when complete.
5. Status becomes **Transcribed**; `transcript.json` exists under the meeting folder.
6. Retry / Re-transcribe overwrites transcript.

## Limits

- Accuracy depends on Apple on-device model / language.
- Long files may need chunking later.
- No diarization (speaker labels) in v1.
- Whisper / other local engines can plug into `TranscriptionEngine` later.
