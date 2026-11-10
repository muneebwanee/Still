import Foundation

/// Applied by the receiver, not just by the browser interface.
public enum RemoteAccessPolicy: Sendable {
    case fullControl, queueOnly
    public func allows(_ action: RemoteCommand.Action) -> Bool {
        switch self {
        case .fullControl: return true
        case .queueOnly: return action == .enqueue
        }
    }
}

public enum PlaybackChoices {
    public static let speeds: [Double] = [0.75, 1, 1.25, 1.5, 2]
    public static let quality = ["Auto", "1080p", "720p"]
    public static func validSpeed(_ value: Double) -> Double { speeds.contains(value) ? value : 1 }
}
