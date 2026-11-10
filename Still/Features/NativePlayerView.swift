import SwiftUI
import AVKit

struct NativePlayerView: UIViewControllerRepresentable {
    @ObservedObject var playback: Playback
    func makeCoordinator() -> Coordinator { Coordinator(playback: playback) }
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController(); controller.player = playback.player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) { controller.player = playback.player }
    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) { controller.delegate = nil; controller.player = nil }
    @MainActor final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let playback: Playback
        init(playback: Playback) { self.playback = playback }
        func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) { playback.pictureInPictureActive = true }
        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) { playback.pictureInPictureActive = false }
        func playerViewController(_ playerViewController: AVPlayerViewController, failedToStartPictureInPictureWithError error: Error) { playback.pictureInPictureActive = false }
        func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) { completionHandler(true) }
    }
}
