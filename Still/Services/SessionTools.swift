import SwiftUI
import WebKit

@MainActor final class SessionTools: ObservableObject {
    @Published private(set) var sleepUntil: Date?
    @Published private(set) var wiping = false
    @Published private(set) var resetID = UUID()
    @Published var wipeError: String?
    private var sleepTask: Task<Void, Never>?
    private let cacheCleaner = LocalCacheCleaner()
    let playback: Playback
    let receiver: Receiver
    let screen: ScreenSession
    init(playback: Playback, receiver: Receiver, screen: ScreenSession) { self.playback = playback; self.receiver = receiver; self.screen = screen }
    func setSleep(minutes: Int?) {
        sleepTask?.cancel(); sleepTask = nil; sleepUntil = nil
        guard let minutes, [15, 30, 60, 90].contains(minutes) else { return }
        sleepUntil = Date().addingTimeInterval(Double(minutes) * 60)
        sleepTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(Double(minutes) * 60)) }
            catch { return }
            guard !Task.isCancelled, let self else { return }
            self.playback.pause(); self.receiver.stop(); self.screen.stop(); self.sleepUntil = nil; self.sleepTask = nil
        }
    }
    func checkSleepDeadline() {
        if let sleepUntil, sleepUntil <= Date() { setSleep(minutes: nil); playback.pause(); receiver.stop(); screen.stop() }
    }
    func wipe() async {
        guard !wiping else { return }
        wiping = true; wipeError = nil
        setSleep(minutes: nil)
        let transientStore = playback.webView?.configuration.websiteDataStore
        screen.stop(); receiver.stop(); receiver.clearActivity()
        playback.stop(); playback.clearQueue()
        await screen.waitForRecording()
        do { try screen.wipeRecordings(); screen.notice = nil } catch { wipeError = "Some recordings could not be deleted. Try again or uninstall Still to remove its app container." }
        UIApplication.shared.isIdleTimerDisabled = false
        if let transientStore { await transientStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) }
        await WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        URLCache.shared.removeAllCachedResponses()
        do { try await cacheCleaner.clear() }
        catch { wipeError = "Playback and pairing were cleared, but some cached files could not be removed. Try again or uninstall Still to remove its app container." }
        if let identifier = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: identifier) }
        playback.resetOptions()
        wiping = false
        // Recreate the UI only after cleanup so settings, fields and sheets lose their old state.
        resetID = UUID()
    }
    var supportSummary: String {
        let state: String
        switch receiver.state {
        case .running: state = "Running"
        case .starting: state = "Starting"
        case .stopped: state = "Stopped"
        case .failed: state = "Unavailable"
        }
        return "Still 1.2.0 (3)\niOS/iPadOS \(UIDevice.current.systemVersion)\nReceiver: \(state)\nPlayback: \(playback.current == nil ? "Idle" : "Active")\nNo device name, network address, pairing token, media URL or title included."
    }
}

// Keep potentially slow filesystem cleanup away from UI rendering.
private actor LocalCacheCleaner {
    func clear() throws {
        guard let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try FileManager.default.removeItem(at: file)
        }
    }
}
