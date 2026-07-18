/// User-facing onboarding copy (kept free of View types for easy coverage).
public enum OnboardingCopy: Sendable {
    public static let privacyBody = """
    Bethal records meetings on this device and stores media, transcripts, summaries, and todos in a folder you choose.

    Processing uses tools already on your machine (Claude CLI, Codex, Grok, and others) — the same idea as Conductor. Bethal does not run a cloud that mines your meeting data.

    You always start recording with an explicit click (or a 1-click reminder). Nothing is captured without you.
    """

    public static let directoryBody =
        "All meetings, transcripts, and todos will live here. You can change this later in Settings."

    public static let providerBody = """
    After each call Bethal can ask which local tool should transcribe and summarize. Pick a default now, or skip and choose every time. You can change this later in Settings.
    """

    public static let privacyShield =
        "No Bethal cloud. Your working directory is the source of truth."
}
