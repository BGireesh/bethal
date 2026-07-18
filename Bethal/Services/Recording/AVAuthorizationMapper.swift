import AVFoundation
import Foundation

/// Maps AVFoundation authorization statuses into domain `PermissionStatus`.
public enum AVAuthorizationMapper: Sendable {
    public static func map(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }
}
