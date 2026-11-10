import SwiftUI
import ReceiverCore

struct SettingsView: View {
    @EnvironmentObject private var receiver: Receiver
    @EnvironmentObject private var screen: ScreenSession
    @EnvironmentObject private var tools: SessionTools
    @Environment(\.dismiss) private var dismiss
    @AppStorage("receiverName") private var name = "Still"
    @AppStorage("queueOnly") private var queueOnly = false
    @State private var pairing = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(receiver.state == .running ? "Ready for videos" : "Receiver is off", systemImage: receiver.state == .running ? "checkmark.circle" : "power")
                    TextField("Screen name", text: $name).onChange(of: name) { _, value in if value.count > 40 { name = String(value.prefix(40)) } }.disabled(receiver.state == .running || receiver.state == .starting)
                    Button(receiver.state == .running || receiver.state == .starting ? "Stop receiver" : "Start receiver") {
                        if receiver.state == .running || receiver.state == .starting { receiver.stop() } else { screen.stop(); receiver.start(name: name) }
                    }
                    if case .failed(let message) = receiver.state { Text(message).font(.footnote).foregroundStyle(.red) }
                    Button("Open Still’s iOS permissions") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                    if receiver.state == .running {
                        Button("Connect another device") { pairing = true }
                        Button("Disconnect all remotes") { receiver.disconnectRemotes() }
                    }
                } header: { Text("This screen") } footer: { Text("Keep Still open while watching. Disconnecting remotes creates a fresh pairing code without stopping your video.") }
                Section {
                    NavigationLink { AppearanceSettingsView() } label: { Label("Look & feel", systemImage: "paintpalette") }
                    NavigationLink { PlaybackSettingsView() } label: { Label("Playback", systemImage: "play.rectangle") }
                    NavigationLink { ScreenConnectionSettingsView() } label: { Label("Screen sharing", systemImage: "rectangle.on.rectangle") }
                    NavigationLink { RecordingsView() } label: { Label("Recordings", systemImage: "record.circle") }
                    NavigationLink { SleepTimerView() } label: { Label("Sleep timer", systemImage: "moon.zzz") }
                    Toggle(isOn: $queueOnly) { Label("Queue-only remotes", systemImage: "text.badge.plus") }
                } header: { Text("Make it yours") } footer: { Text("Queue-only mode lets other devices add videos. You keep control of play, pause, volume and the current video.") }
                Section {
                    NavigationLink { PrivacySettingsView() } label: { Label("Privacy & data", systemImage: "hand.raised") }
                    NavigationLink { LegalLibraryView() } label: { Label("Offline legal library", systemImage: "doc.text") }
                    NavigationLink { DocumentView(document: .help) } label: { Label("Help connecting", systemImage: "questionmark.circle") }
                    NavigationLink { DocumentView(document: .compatibility) } label: { Label("What works", systemImage: "checkmark.rectangle") }
                    ShareLink(item: tools.supportSummary) { Label("Share a safe support summary", systemImage: "square.and.arrow.up") }
                    Link(destination: URL(string: "https://github.com/muneebwanee")!) { Label("Contact the developer", systemImage: "arrow.up.right") }
                } header: { Text("Help & trust") } footer: { Text("Support summaries exclude video links, titles, Wi-Fi addresses and pairing codes. Nothing is sent unless you choose to share it.") }
                Section {
                    HStack { Text("Still").font(.headline); Spacer(); Text("1.2.0 (3)").foregroundStyle(.secondary) }
                    Link("Developed by muneebwanee", destination: URL(string: "https://github.com/muneebwanee")!)
                    Text("Zero developer telemetry. No paid feature gates.").font(.footnote).foregroundStyle(.secondary)
                }
            }.disabled(tools.wiping)
                .overlay { if tools.wiping { ProgressView("Clearing local data…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18)) } }
                .navigationTitle("Settings").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.sheet(isPresented: $pairing) { PairingView() }.interactiveDismissDisabled(tools.wiping)
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("compactLayout") private var compact = false
    @AppStorage("haptics") private var haptics = true
    var body: some View {
        Form {
            Section { Picker("Appearance", selection: $appearance) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) } } } footer: { Text("System follows your iPhone or iPad’s light and dark schedule.") }
            Section("Color theme") { ThemePicker() }
            Section { Toggle("Compact layout", isOn: $compact); Toggle("Gentle haptics", isOn: $haptics) } footer: { Text("Haptics mark meaningful actions on supported devices. Still follows Dynamic Type, Reduce Motion and your system accessibility settings.") }
        }.navigationTitle("Look & feel").navigationBarTitleDisplayMode(.inline)
    }
}

struct PlaybackSettingsView: View {
    @EnvironmentObject private var playback: Playback
    @AppStorage("keepAwake") private var keepAwake = true
    @AppStorage("autoAdvance") private var autoAdvance = true
    @AppStorage("skipSeconds") private var skip = 15
    @AppStorage("backgroundAudio") private var backgroundAudio = false
    var body: some View {
        Form {
            Section { Toggle("Keep screen awake", isOn: $keepAwake); Toggle("Background stream audio", isOn: $backgroundAudio); Toggle("Play next automatically", isOn: $autoAdvance); Toggle("Repeat current video", isOn: $playback.repeatOne) } footer: { Text("Repeat takes priority over playing the next video. Receiving and screen sharing stop in the background. Compatible direct streams can continue audio if enabled, or use native Picture in Picture. YouTube pauses.") }
            Section {
                Picker("Playback speed", selection: $playback.speed) { ForEach(PlaybackChoices.speeds, id: \.self) { Text(String(format: "%g×", $0)).tag($0) } }
                Picker("Skip buttons", selection: $skip) { ForEach([10, 15, 30], id: \.self) { Text("\($0) seconds").tag($0) } }
                Picker("Stream quality", selection: $playback.quality) { ForEach(PlaybackChoices.quality, id: \.self) { Text($0) } }
                HStack { Image(systemName: "speaker.wave.1"); Slider(value: $playback.volume, in: 0...1).accessibilityLabel("Player volume"); Image(systemName: "speaker.wave.3") }
            } header: { Text("Fine tuning") } footer: { Text("Speed depends on the video provider. Quality is a ceiling for compatible HLS streams; YouTube manages its own quality. Player volume is separate from device volume.") }
            Section { Button("Stop video", role: .destructive) { playback.stop() }.disabled(playback.current == nil) }
        }.navigationTitle("Playback").navigationBarTitleDisplayMode(.inline)
    }
}

struct SleepTimerView: View {
    @EnvironmentObject private var tools: SessionTools
    var body: some View {
        Form {
            Section {
                if let end = tools.sleepUntil { LabeledContent("Ends at", value: end.formatted(date: .omitted, time: .shortened)); Button("Cancel timer") { tools.setSleep(minutes: nil) } }
                else { Text("No timer set").foregroundStyle(.secondary) }
            } footer: { Text("When time is up, Still pauses the video and disconnects all remotes. Nothing plays automatically afterward.") }
            Section("Stop after") { ForEach([15, 30, 60, 90], id: \.self) { minutes in Button("\(minutes) minutes") { tools.setSleep(minutes: minutes) } } }
        }.navigationTitle("Sleep timer").navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject private var receiver: Receiver
    @EnvironmentObject private var playback: Playback
    @EnvironmentObject private var tools: SessionTools
    @AppStorage("allowYouTube") private var allowYouTube = true
    @State private var confirmWipe = false
    var body: some View {
        Form {
            Section {
                Label("Zero developer telemetry", systemImage: "checkmark.shield")
                Text("No analytics, ads SDK, tracking IDs or automatic crash uploads. Screen sharing uses your configured connection service. Your queue stays in memory; explicit recordings stay on this device.").foregroundStyle(.secondary)
                Toggle("Allow YouTube playback", isOn: $allowYouTube)
                    .onChange(of: allowYouTube) { _, value in playback.setYouTubeAllowed(value) }
            } footer: { Text("YouTube and video hosts receive your playback requests under their own policies. Turning YouTube off stops its current video and removes its queued links. Direct media hosts still receive requests when you play their videos.") }
            Section {
                Button("Disconnect all remotes") { receiver.disconnectRemotes() }.disabled(receiver.state != .running)
                NavigationLink("Data safety & local wipe") { DocumentView(document: .dataSafety) }
                NavigationLink("Full privacy policy") { DocumentView(document: .privacy) }
                Button("Wipe local data now", role: .destructive) { confirmWipe = true }.disabled(tools.wiping)
            } header: { Text("Your control") } footer: { Text("Wipe immediately stops playback and receiving, then clears the queue, pairing, recordings, preferences, web data and app caches. It returns Still to its welcome screen. It cannot erase records held by iOS, other devices or media providers.") }
        }.disabled(tools.wiping)
            .overlay { if tools.wiping { ProgressView("Clearing local data…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18)) } }
            .navigationBarBackButtonHidden(tools.wiping)
            .navigationTitle("Privacy & data").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Wipe Still’s local data?", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("Stop & wipe local data", role: .destructive) { Task { await tools.wipe() } }
            } message: { Text("Your video stops, all remotes disconnect, and settings reset. This cannot be undone.") }
    }
}

struct WelcomeView: View {
    @Binding var onboarded: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Image(systemName: "play.rectangle.on.rectangle").font(.system(size: 48, weight: .ultraLight)).padding(.top, 30)
                    Text("Your next video.\nA little bigger.").font(.largeTitle.weight(.medium)).tracking(-1)
                    Text("Watch a video from another device on this iPhone or iPad. No account. No setup puzzle.").font(.title3).foregroundStyle(.secondary)
                    Label("Start Still on this screen", systemImage: "1.circle")
                    Label("Scan its code with your other device", systemImage: "2.circle")
                    Label("Paste a video link and press Play", systemImage: "3.circle")
                    Text("Link mode uses the same Wi-Fi. Screen mode can cross networks when its connection service is configured. Link mode won’t appear in YouTube’s Cast menu. Separate screen mode supports Android Sender and compatible computer browsers. YouTube and media providers receive playback requests.").font(.footnote).foregroundStyle(.secondary)
                    NavigationLink("Read privacy & legal pages offline") { LegalLibraryView() }.font(.footnote)
                    Button { onboarded = true } label: { Text("Let’s watch").font(.headline).frame(maxWidth: .infinity).padding(12) }.buttonStyle(.borderedProminent)
                    Text("Developed by muneebwanee").font(.caption).foregroundStyle(.tertiary)
                }.padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
        }
    }
}
