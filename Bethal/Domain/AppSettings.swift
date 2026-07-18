import Foundation

/// User preferences stored under `.bethal/settings.json`.
public struct AppSettings: Codable, Equatable, Sendable {
    public var defaultCaptureMode: CaptureMode
    public var defaultAIProviderID: String?
    /// When true, post-call flow always asks which local AI tool to use.
    public var askEveryTimeForProvider: Bool
    public var calendarAutoDetectEnabled: Bool
    public var calendarRemindMinutesBefore: Int

    public init(
        defaultCaptureMode: CaptureMode = .audioOnly,
        defaultAIProviderID: String? = nil,
        askEveryTimeForProvider: Bool = true,
        calendarAutoDetectEnabled: Bool = true,
        calendarRemindMinutesBefore: Int = 2
    ) {
        self.defaultCaptureMode = defaultCaptureMode
        self.defaultAIProviderID = defaultAIProviderID
        self.askEveryTimeForProvider = askEveryTimeForProvider
        self.calendarAutoDetectEnabled = calendarAutoDetectEnabled
        self.calendarRemindMinutesBefore = calendarRemindMinutesBefore
    }

    public static let `default` = AppSettings()
}
