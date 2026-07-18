import AVFoundation
import CoreGraphics
import Foundation

/// Production permission checker using AVFoundation + ScreenCapture TCC helpers.
///
/// Not unit-tested against real TCC; use `MockPermissionChecker` in tests.
public struct SystemPermissionChecker: PermissionChecking, Sendable {
    public init() {}

    public func microphoneStatus() -> PermissionStatus {
        AVAuthorizationMapper.map(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    public func screenStatus() -> PermissionStatus {
        if CGPreflightScreenCaptureAccess() {
            return .authorized
        }
        return .notDetermined
    }

    public func requestMicrophoneAccess() async -> PermissionStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        return granted ? .authorized : .denied
    }

    public func requestScreenAccess() async -> PermissionStatus {
        let granted = CGRequestScreenCaptureAccess()
        return granted ? .authorized : .denied
    }
}
