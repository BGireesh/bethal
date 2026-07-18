import Foundation

/// Reads and requests capture-related permissions.
public protocol PermissionChecking: Sendable {
    func microphoneStatus() -> PermissionStatus
    func screenStatus() -> PermissionStatus
    func requestMicrophoneAccess() async -> PermissionStatus
    func requestScreenAccess() async -> PermissionStatus
}

/// Deterministic permissions for unit tests.
public final class MockPermissionChecker: PermissionChecking, @unchecked Sendable {
    public var microphone: PermissionStatus
    public var screen: PermissionStatus
    public var microphoneRequestResult: PermissionStatus
    public var screenRequestResult: PermissionStatus
    public private(set) var microphoneRequestCount = 0
    public private(set) var screenRequestCount = 0

    public init(
        microphone: PermissionStatus = .authorized,
        screen: PermissionStatus = .authorized,
        microphoneRequestResult: PermissionStatus? = nil,
        screenRequestResult: PermissionStatus? = nil
    ) {
        self.microphone = microphone
        self.screen = screen
        self.microphoneRequestResult = microphoneRequestResult ?? microphone
        self.screenRequestResult = screenRequestResult ?? screen
    }

    public func microphoneStatus() -> PermissionStatus { microphone }
    public func screenStatus() -> PermissionStatus { screen }

    public func requestMicrophoneAccess() async -> PermissionStatus {
        microphoneRequestCount += 1
        microphone = microphoneRequestResult
        return microphone
    }

    public func requestScreenAccess() async -> PermissionStatus {
        screenRequestCount += 1
        screen = screenRequestResult
        return screen
    }
}
