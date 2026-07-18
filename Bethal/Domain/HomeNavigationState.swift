/// Pure navigation state for the home shell sidebar.
public struct HomeNavigationState: Equatable, Sendable {
    public var selectedSection: AppSection

    public init(selectedSection: AppSection = .meetings) {
        self.selectedSection = selectedSection
    }

    public mutating func select(_ section: AppSection) {
        selectedSection = section
    }

    public var selectedTitle: String { selectedSection.title }
}
