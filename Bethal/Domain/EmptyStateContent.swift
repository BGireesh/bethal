/// Copy for empty list screens (meetings / todos) until capture lands.
public struct EmptyStateContent: Equatable, Sendable {
    public var title: String
    public var message: String
    public var systemImage: String

    public init(title: String, message: String, systemImage: String) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    public static let meetings = EmptyStateContent(
        title: "No meetings yet",
        message: "When you record a call, it will show up here with transcript and summary after processing.",
        systemImage: "waveform.badge.magnifyingglass"
    )

    public static let todos = EmptyStateContent(
        title: "No todos yet",
        message: "Action items from processed meetings will appear in this global list. You can complete them or set reminders later.",
        systemImage: "checklist"
    )
}
