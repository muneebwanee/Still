import SwiftUI

@main struct StillApp: App {
    @StateObject private var playback: Playback
    @StateObject private var receiver: Receiver
    @StateObject private var tools: SessionTools
    @StateObject private var screen: ScreenSession
    @AppStorage("backgroundAudio") private var backgroundAudio = false
    @AppStorage("theme") private var theme = AppTheme.graphite.rawValue
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("keepAwake") private var keepAwake = true
    @AppStorage("autoAdvance") private var autoAdvance = true
    @Environment(\.scenePhase) private var scenePhase
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting-reset"), let identifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: identifier)
        }
        #endif
        let playback = Playback()
        _playback = StateObject(wrappedValue: playback)
        let receiver = Receiver(playback: playback)
        _receiver = StateObject(wrappedValue: receiver)
        let screen = ScreenSession(playback: playback, receiver: receiver)
        _screen = StateObject(wrappedValue: screen)
        _tools = StateObject(wrappedValue: SessionTools(playback: playback, receiver: receiver, screen: screen))
    }
    var body: some Scene {
        WindowGroup {
            RootView().id(tools.resetID).environmentObject(playback).environmentObject(receiver).environmentObject(tools).environmentObject(screen)
                .tint((AppTheme(rawValue: theme) ?? .graphite).color)
                .disabled(tools.wiping)
                .overlay { if tools.wiping { ZStack { Color(uiColor: .systemBackground).opacity(0.96).ignoresSafeArea(); VStack(spacing: 16) { ProgressView(); Text("Clearing this device…").font(.headline); Text("Playback stopped. Remotes disconnected.").font(.footnote).foregroundStyle(.secondary) } }.accessibilityElement(children: .contain) } }
                .preferredColorScheme(appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil)
                .onAppear { playback.autoAdvance = autoAdvance }
                .onChange(of: autoAdvance) { _, value in playback.autoAdvance = value }
                .onChange(of: keepAwake) { _, _ in updateIdleTimer() }
                .onChange(of: receiver.state) { _, _ in updateIdleTimer() }
                .onChange(of: screen.state) { _, _ in updateIdleTimer() }
                .onChange(of: playback.current) { _, _ in updateIdleTimer() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background {
                        receiver.stop(); screen.stop()
                        if playback.current?.kind != .stream || (!backgroundAudio && !playback.pictureInPictureActive) { playback.pause() }
                        UIApplication.shared.isIdleTimerDisabled = false
                    }
                    else if phase == .active { tools.checkSleepDeadline(); updateIdleTimer() }
                }
        }
    }
    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = keepAwake && scenePhase == .active && (receiver.state == .running || playback.current != nil || screen.isActive)
    }
}
