import SwiftUI
import ReceiverCore
import CoreImage.CIFilterBuiltins

struct RootView: View {
    @EnvironmentObject private var playback: Playback
    @EnvironmentObject private var receiver: Receiver
    @EnvironmentObject private var tools: SessionTools
    @EnvironmentObject private var screen: ScreenSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("onboarded") private var onboarded = false
    @AppStorage("receiverName") private var name = "Still"
    @AppStorage("theme") private var theme = AppTheme.graphite.rawValue
    @AppStorage("compactLayout") private var compact = false
    @AppStorage("haptics") private var haptics = true
    @AppStorage("skipSeconds") private var skipSeconds = 15
    @State private var manageQueue = false
    @State private var screenSharing = false
    @State private var settings = false
    @State private var addVideo = false
    @State private var fullScreen = false
    @State private var pairing = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 18 : 28) {
                    header
                    if let message = tools.wipeError { Text(message).font(.footnote).foregroundStyle(.red) }
                    if let end = tools.sleepUntil { Label("Sleep timer · " + end.formatted(date: .omitted, time: .shortened), systemImage: "moon.zzz").font(.caption).foregroundStyle(.secondary) }
                    receiverCard
                    Button { screenSharing = true } label: {
                        HStack(spacing: 14) { Image(systemName: "rectangle.on.rectangle"); VStack(alignment: .leading, spacing: 4) { Text(screen.isActive ? "Screen sharing is active" : "Receive a whole screen").font(.subheadline.weight(.medium)); Text("Android & supported computer browsers").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(18).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain)
                    if let track = screen.track, !screenSharing { ReceivedScreenView(track: track).aspectRatio(16/9, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 20)) }
                    nowShowing
                    queue
                    HStack(spacing: 7) { Image(systemName: "lock.shield"); Text("Your network. Your screen. No account.") }.font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.bottom, 12)
                }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }.background(Color(uiColor: .systemGroupedBackground))
                .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: receiver.state) { old, new in if old != .running, new == .running, !settings { pairing = true } }
        .sheet(isPresented: $screenSharing) { ScreenShareView() }
        .sheet(isPresented: $manageQueue) { QueueView() }
        .sheet(isPresented: $settings) { SettingsView() }
        .sheet(isPresented: $addVideo) { AddVideoView() }
        .sheet(isPresented: $pairing) { PairingView() }
        .fullScreenCover(isPresented: $fullScreen) {
            ZStack(alignment: .topTrailing) { Color.black.ignoresSafeArea(); PlayerView().ignoresSafeArea(); Button { fullScreen = false } label: { Image(systemName: "xmark").font(.headline).padding(16).background(.ultraThinMaterial, in: Circle()) }.padding(20).accessibilityLabel("Close full screen") }.preferredColorScheme(.dark)
        }
        .sheet(isPresented: Binding(get: { !onboarded }, set: { if !$0 { onboarded = true } })) { WelcomeView(onboarded: $onboarded).interactiveDismissDisabled() }
    }
    private var receiverCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("YOUR RECEIVER").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                Spacer()
                Label(receiver.state == .running ? "Live" : "Offline", systemImage: "circle.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(receiver.state == .running ? Color.green : Color.secondary)
            }
            Text(receiver.state == .running ? "Ready for\nyour next video." : "Your video.\nThis screen.")
                .font(.system(.largeTitle, design: .rounded, weight: .medium)).tracking(-1.2).fixedSize(horizontal: false, vertical: true)
            Text(receiver.state == .running ? "Keep Still open. Your next video is a scan away." : "Bring a video from another device to your iPhone or iPad.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button {
                if haptics { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
                withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 1)) {
                    if receiver.state == .running || receiver.state == .starting { receiver.stop() } else { screen.stop(); receiver.start(name: name) }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: receiver.state == .running ? "stop.fill" : "dot.radiowaves.left.and.right")
                    Text(receiver.state == .running ? "Stop receiver" : receiver.state == .starting ? "Cancel starting" : "Start receiver")
                    Spacer(); Image(systemName: "arrow.up.right")
                }.font(.subheadline.weight(.semibold)).padding(18).foregroundStyle(Color(uiColor: .systemBackground)).background((AppTheme(rawValue: theme) ?? .graphite).color, in: RoundedRectangle(cornerRadius: 18))
            }.buttonStyle(QuietPress())
            if case .failed(let message) = receiver.state {
                Label(message, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                Button("Check iOS permissions") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }.font(.footnote.weight(.medium))
            }
            if receiver.state == .running {
                Button { pairing = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "qrcode").font(.title)
                        VStack(alignment: .leading, spacing: 4) { Text("Connect another device").font(.subheadline.weight(.medium)); Text("Scan a code. Send a video.").font(.caption).foregroundStyle(.secondary) }
                        Spacer(); Image(systemName: "chevron.right").font(.caption)
                    }.padding(16).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).transition(.opacity)
            }
        }.padding(compact ? 18 : 24).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
    }
    private var nowShowing: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Now showing").font(.title3.weight(.semibold)); Spacer()
                Button { addVideo = true } label: { Image(systemName: "plus").frame(width: 44, height: 44).background(.quaternary, in: Circle()) }.accessibilityLabel("Add video link")
            }
            PlayerView().aspectRatio(16 / 9, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 20))
            if let current = playback.current {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) { Text(current.title).font(.headline).lineLimit(2); Text(current.source).font(.caption).foregroundStyle(.secondary) }
                    Spacer(); if current.kind == .stream { Button { fullScreen = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 44, height: 44) }.accessibilityLabel("Full screen") }
                }
                playbackControls
            }
            if let error = playback.error { VStack(alignment: .leading, spacing: 8) { Text(error).font(.footnote).foregroundStyle(.red); if let url = playback.current?.url { Link("Open original", destination: url).font(.footnote.weight(.semibold)) } } }
        }
    }
    private var header: some View {
        HStack {
            HStack(spacing: 9) { Image(systemName: "rectangle.inset.filled.and.person.filled").font(.title3); Text("still").font(.system(.title2, design: .rounded, weight: .semibold)).tracking(-0.8) }
            Spacer()
            Button { settings = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44).background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle()) }.accessibilityLabel("Settings")
        }
    }
    private var playbackControls: some View {
        VStack(spacing: 10) {
            if playback.duration > 0 {
                Slider(value: Binding(get: { min(playback.position, playback.duration) }, set: { playback.seek($0) }), in: 0...max(1, playback.duration)).accessibilityLabel("Playback position")
                HStack { Text(time(playback.position)); Spacer(); Text(time(playback.duration)) }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 24) {
                Button { playback.seek(playback.position - Double(skipSeconds)) } label: { Image(systemName: "gobackward.\(skipSeconds)").frame(width: 44, height: 44) }.accessibilityLabel("Back \(skipSeconds) seconds")
                Button { playback.isPlaying ? playback.pause() : playback.play() } label: { Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill").font(.title2).frame(width: 56, height: 56).background(.quaternary, in: Circle()) }.accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
                Button { playback.seek(playback.position + Double(skipSeconds)) } label: { Image(systemName: "goforward.\(skipSeconds)").frame(width: 44, height: 44) }.accessibilityLabel("Forward \(skipSeconds) seconds")
                Spacer()
                Button { playback.next() } label: { Image(systemName: "forward.end.fill").frame(width: 44, height: 44) }.accessibilityLabel("Next video")
            }
            if playback.isBuffering { HStack { ProgressView(); Text("Connecting to video…").font(.caption).foregroundStyle(.secondary) } }
        }
    }
    private var queue: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Up next").font(.title3.weight(.semibold)); Text("\(playback.queue.count)").font(.caption).foregroundStyle(.secondary); Spacer(); if !playback.queue.isEmpty { Button("Edit") { manageQueue = true }.font(.caption) } }
            if playback.queue.isEmpty { Text("A quiet queue. Add something worth watching.").font(.callout).foregroundStyle(.secondary).padding(.vertical, 8) }
            if playback.current == nil, !playback.queue.isEmpty { Button("Play next video", systemImage: "play.fill") { screen.stop(); playback.next() }.font(.subheadline.weight(.medium)) }
            ForEach(Array(playback.queue.enumerated()), id: \.element.id) { index, media in
                HStack(spacing: 14) {
                    Text(String(format: "%02d", index + 1)).font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                    VStack(alignment: .leading, spacing: 4) { Text(media.title).font(.subheadline).lineLimit(1); Text(media.source).font(.caption).foregroundStyle(.secondary) }
                    Spacer(); Button { playback.remove(IndexSet(integer: index)) } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Remove \(media.title)")
                }
            }
        }
    }
    private func time(_ seconds: Double) -> String { let total = Int(max(0, seconds)); return total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60) : String(format: "%d:%02d", total / 60, total % 60) }
}

struct QuietPress: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View { configuration.label.opacity(configuration.isPressed ? 0.85 : 1).scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1).animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed) }
}

struct AddVideoView: View {
    @EnvironmentObject private var playback: Playback
    @EnvironmentObject private var screen: ScreenSession
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var title = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Video link") { TextField("https://…", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled(); TextField("Title (optional)", text: $title) }
                Section { Button("Play now") { submit(queue: false) }; Button("Add to queue") { submit(queue: true) } }.disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Section { Text("YouTube links and HTTPS MP4, MOV, M4V, MP3, M4A and HLS (.m3u8) streams. YouTube videos must allow embedding. No video downloading or DRM bypass.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Add a video").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
    private func submit(queue: Bool) {
        do { let media = try Media(url, title: title); if queue { try playback.enqueue(media, startIfIdle: !screen.isActive) } else { screen.stop(); try playback.load(media) }; dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

struct PairingView: View {
    @EnvironmentObject private var receiver: Receiver
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Connect in\nthree easy steps.").font(.largeTitle.weight(.medium)).multilineTextAlignment(.center).padding(.top, 20)
                    if let url = receiver.pairingURL {
                        if let qr = qrImage(url.absoluteString) { Image(uiImage: qr).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 240).padding(20).background(.white, in: RoundedRectangle(cornerRadius: 24)).accessibilityLabel("Pairing QR code. Use the share button for an accessible link.") }
                        Text("1. Connect both devices to the same Wi-Fi.\n2. Scan this code with the other device.\n3. Paste a video link and press Play.").font(.callout).lineSpacing(8).frame(maxWidth: .infinity, alignment: .leading)
                        ShareLink(item: url) { Label("Share pairing link", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding() }.buttonStyle(.borderedProminent)
                        DisclosureGroup("Can’t scan the code?") {
                            Text("Open this full link in the other device’s browser:").font(.footnote)
                            Text(url.absoluteString).font(.caption.monospaced()).textSelection(.enabled).padding(.top, 6)
                        }.font(.footnote).foregroundStyle(.secondary)
                        Text("The link controls this receiver until you stop it. Share only with people you trust. Local pairing uses HTTP; use a trusted private network.").font(.footnote).foregroundStyle(.secondary)
                    } else { ContentUnavailableView("Receiver is offline", systemImage: "wifi.slash", description: Text("Start the receiver to create a fresh pairing link.")) }
                }.padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
            }.navigationTitle("Connect").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func qrImage(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(text.utf8)
        guard let output = filter.outputImage, let cg = CIContext().createCGImage(output.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), from: output.extent.applying(CGAffineTransform(scaleX: 8, y: 8))) else { return nil }
        return UIImage(cgImage: cg)
    }
}
