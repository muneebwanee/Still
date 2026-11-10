import AVKit
import SwiftUI
import Combine
import ReceiverCore
import WebKit

@MainActor final class Playback: ObservableObject {
    @Published private(set) var current: Media?
    @Published private(set) var queue: [Media] = []
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var position = 0.0
    @Published private(set) var duration = 0.0
    @Published var pictureInPictureActive = false
    @Published var error: String?
    @Published var volume: Double = 1 { didSet { player.volume = Float(volume); youtube("setVolume", argument: volume * 100) } }
    @Published var quality = "Auto" { didSet { UserDefaults.standard.set(quality, forKey: "quality"); applyQuality() } }
    @Published var speed: Double = 1 { didSet {
        UserDefaults.standard.set(speed, forKey: "speed")
        if current?.kind == .stream, player.rate != 0 { player.rate = Float(speed) }
        youtube("setPlaybackRate", argument: speed)
    } }
    @Published var repeatOne = false { didSet { UserDefaults.standard.set(repeatOne, forKey: "repeatOne") } }
    @Published var allowYouTube = true
    @Published var autoAdvance = true
    let player = AVPlayer()
    weak var webView: WKWebView?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var controlObserver: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?

    init() {
        let savedQuality = UserDefaults.standard.string(forKey: "quality") ?? "Auto"
        quality = PlaybackChoices.quality.contains(savedQuality) ? savedQuality : "Auto"
        speed = PlaybackChoices.validSpeed(UserDefaults.standard.double(forKey: "speed"))
        repeatOne = UserDefaults.standard.bool(forKey: "repeatOne")
        allowYouTube = UserDefaults.standard.object(forKey: "allowYouTube") as? Bool ?? true
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self, self.current?.kind == .stream else { return }
                self.position = time.seconds.isFinite ? time.seconds : 0
                let duration = self.player.currentItem?.duration.seconds ?? 0
                self.duration = duration.isFinite ? duration : 0
            }
        }
        controlObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor in
                guard self?.current?.kind == .stream else { return }
                self?.isPlaying = status == .playing
                self?.isBuffering = status == .waitingToPlayAtSpecifiedRate
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let self, let item = note.object as? AVPlayerItem, item === self.player.currentItem else { return }
                self.finished()
            }
        }
    }
    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
    func validate(_ media: Media) throws {
        if case .youtube = media.kind, !allowYouTube { throw PlaybackError.youtubeDisabled }
    }
    func load(_ media: Media) throws {
        try validate(media)
        player.pause(); youtube("stopVideo"); player.replaceCurrentItem(with: nil)
        statusObserver = nil; webView?.stopLoading(); webView?.loadHTMLString("", baseURL: nil); webView = nil
        current = media; error = nil; position = 0; duration = 0; isPlaying = false; isBuffering = true
        guard media.kind == .stream else { return }
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback); try AVAudioSession.sharedInstance().setActive(true) }
        catch { self.error = "Audio could not start: \(error.localizedDescription)" }
        let item = AVPlayerItem(url: media.url)
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let message = item.status == .failed ? item.error?.localizedDescription ?? "This stream could not be played." : nil
            Task { @MainActor in
                guard let self, item === self.player.currentItem else { return }
                if let message { self.error = message; self.isBuffering = false }
            }
        }
        player.replaceCurrentItem(with: item); applyQuality(); player.playImmediately(atRate: Float(speed))
    }
    func enqueue(_ media: Media, startIfIdle: Bool = true) throws {
        try validate(media)
        if current == nil, startIfIdle { try load(media); return }
        guard queue.count < 20 else { throw PlaybackError.queueFull }
        queue.append(media)
    }
    func remove(_ offsets: IndexSet) { queue.remove(atOffsets: offsets) }
    func move(_ from: IndexSet, to: Int) { queue.move(fromOffsets: from, toOffset: to) }
    func clearQueue() { queue.removeAll() }
    func next() {
        guard !queue.isEmpty else { stop(); return }
        let media = queue.removeFirst()
        do { try load(media) } catch { self.error = error.localizedDescription }
    }
    func playQueued(_ id: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        do { try validate(queue[index]); let media = queue.remove(at: index); try load(media) }
        catch { self.error = error.localizedDescription }
    }
    func finished() { isPlaying = false; if repeatOne { seek(0); play() } else if autoAdvance, !queue.isEmpty { next() } }
    func play() { if current?.kind == .stream { player.playImmediately(atRate: Float(speed)) } else { youtube("playVideo") } }
    func pause() { player.pause(); youtube("pauseVideo"); isPlaying = false }
    func stop() { pictureInPictureActive = false; pause(); youtube("stopVideo"); webView?.stopLoading(); webView?.loadHTMLString("", baseURL: nil); statusObserver = nil; current = nil; webView = nil; player.replaceCurrentItem(with: nil); position = 0; duration = 0; isBuffering = false; error = nil }
    func seek(_ seconds: Double) {
        guard seconds.isFinite, duration > 0 else { return }
        let target = max(0, min(seconds, duration))
        if current?.kind == .stream { player.seek(to: CMTime(seconds: target, preferredTimescale: 600)) }
        else { youtube("seekTo", argument: target) }
    }
    func setYouTubeAllowed(_ value: Bool) {
        allowYouTube = value
        if !value {
            if let current, case .youtube = current.kind { stop() }
            queue.removeAll { if case .youtube = $0.kind { return true }; return false }
        }
    }
    func resetOptions() {
        // Set defaults explicitly; property observers write only non-identifying preferences.
        quality = "Auto"; speed = 1; volume = 1; repeatOne = false; autoAdvance = true; allowYouTube = true
    }
    func applyQuality() {
        // A ceiling, not a guarantee. HLS must actually expose variants.
        player.currentItem?.preferredMaximumResolution = quality == "720p" ? CGSize(width: 1280, height: 720) : quality == "1080p" ? CGSize(width: 1920, height: 1080) : .zero
    }
    func webEvent(_ event: [String: Any]) {
        if event["ready"] as? Bool == true { isBuffering = false }
        if let message = event["message"] as? String { error = message; isBuffering = false }
        if let state = event["state"] as? Int { isPlaying = state == 1; isBuffering = state == 3; if state == 0 { finished() } }
        if let time = event["time"] as? Double, time.isFinite { position = max(0, time) }
        if let length = event["duration"] as? Double, length.isFinite { duration = max(0, length) }
        if let code = event["error"] as? Int { error = "YouTube couldn’t play this video (\(code)). The owner may restrict embedding. Try another video or open it in YouTube."; isBuffering = false }
    }
    private func youtube(_ method: String, argument: Double? = nil) {
        let args = argument.map { String($0) } ?? ""
        webView?.evaluateJavaScript("if(window.player && typeof player.\(method)==='function'){player.\(method)(\(args))}", completionHandler: nil)
    }
}
enum PlaybackError: LocalizedError {
    case queueFull, youtubeDisabled
    var errorDescription: String? {
        switch self {
        case .queueFull: return "The queue is full. Remove a video before adding another."
        case .youtubeDisabled: return "YouTube playback is off in Privacy & Data. Enable it there, or use a direct video stream."
        }
    }
}
