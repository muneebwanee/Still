import SwiftUI
import WebRTC
import AVKit
import CoreImage.CIFilterBuiltins

struct ReceivedScreenView: UIViewRepresentable {
    let track: RTCVideoTrack
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> RTCMTLVideoView { let view = RTCMTLVideoView(frame: .zero); view.videoContentMode = .scaleAspectFit; view.backgroundColor = .black; return view }
    func updateUIView(_ view: RTCMTLVideoView, context: Context) { if context.coordinator.track !== track { context.coordinator.track?.remove(view); track.add(view); context.coordinator.track = track } }
    static func dismantleUIView(_ view: RTCMTLVideoView, coordinator: Coordinator) { coordinator.track?.remove(view); coordinator.track = nil }
    final class Coordinator { var track: RTCVideoTrack? }
}

struct ScreenShareView: View {
    @EnvironmentObject private var screen: ScreenSession
    @Environment(\.dismiss) private var dismiss
    @State private var fullScreen = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Their screen.\nYour front row.").font(.largeTitle.weight(.medium)).tracking(-1)
                    Text("Invite an Android phone or a supported computer browser. Nearby or across the internet.").foregroundStyle(.secondary)
                    if let track = screen.track {
                        ReceivedScreenView(track: track).aspectRatio(16/9, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 18))
                        Button("Full screen", systemImage: "arrow.up.left.and.arrow.down.right") { fullScreen = true }
                        recordingControls
                    } else if let url = screen.invitation {
                        SharingQRCode(text: url.absoluteString).frame(maxWidth: 230).frame(maxWidth: .infinity)
                        Text("1. Open this invitation on the other device.\n2. Choose a screen in the browser or Android sender.\n3. Allow screen capture on that device.").font(.callout).lineSpacing(8)
                        ShareLink(item: url) { Label("Share screen invitation", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(10) }.buttonStyle(.borderedProminent)
                        Text("This link lets one device share to you. Keep it private. Android needs the Still Sender companion. iPhone/iPad sending is not supported in this version.").font(.footnote).foregroundStyle(.secondary)
                    }
                    if !screen.isActive { Button("Create an invitation", systemImage: "rectangle.on.rectangle") { screen.start() }.buttonStyle(.borderedProminent) }
                    else { Label(status, systemImage: screen.state == .viewing ? "checkmark.circle" : "antenna.radiowaves.left.and.right").font(.subheadline); Button("End screen sharing", role: .destructive) { screen.stop() } }
                    if case .failed(let message) = screen.state { Text(message).font(.footnote).foregroundStyle(.red) }
                    if let notice = screen.notice { Text(notice).font(.footnote).foregroundStyle(.secondary) }
                    NavigationLink("Recordings on this device") { RecordingsView() }
                    NavigationLink("Connection settings") { ScreenConnectionSettingsView() }
                    Text("Screen video only. Keep the receiving app open. Long-distance sharing needs a configured connection service and often a TURN relay. Connection quality depends on both networks; Still cannot guarantee zero delay or an uninterrupted connection.").font(.footnote).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }.navigationTitle("Receive a screen").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.fullScreenCover(isPresented: $fullScreen) {
            ZStack(alignment: .topTrailing) { Color.black.ignoresSafeArea(); if let track = screen.track { ReceivedScreenView(track: track).ignoresSafeArea() }; Button { fullScreen = false } label: { Image(systemName: "xmark").padding(16).background(.regularMaterial, in: Circle()) }.padding().accessibilityLabel("Close full screen") }.preferredColorScheme(.dark)
        }
    }
    private var status: String { switch screen.state { case .connecting: return "Connecting…"; case .waiting: return "Waiting for your other device"; case .viewing: return "Screen connected"; case .reconnecting: return "Reconnecting…"; default: return "Screen sharing stopped" } }
    private var recordingControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(screen.isRecording ? "Stop & save recording" : "Record this screen", systemImage: screen.isRecording ? "stop.circle.fill" : "record.circle") { screen.isRecording ? screen.stopRecording() : screen.startRecording() }
                .disabled(screen.finishingRecording || (!screen.isRecording && !screen.recordingAllowed))
            Text(screen.isRecording ? "Recording screen video on this device. No audio. Stops at 30 minutes or low storage." : screen.recordingAllowed ? "The sender allowed recording. Video stays on this device until you share it." : "Recording is off. The sender must allow it before joining.").font(.footnote).foregroundStyle(screen.isRecording ? Color.red : Color.secondary)
            if screen.finishingRecording { ProgressView("Saving recording…") }
        }
    }
}

struct ScreenConnectionSettingsView: View {
    @AppStorage("sharingServer") private var server = ""
    var body: some View {
        Form {
            Section { TextField("https://share.your-domain.com", text: $server).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled() } header: { Text("Connection service") } footer: { Text("One-time setup for this installation. Use a service you trust. Its operator processes connection metadata and may relay encrypted media. The project includes server code, but no public service is preconfigured. Restart the invitation after changing this address.") }
            Section { Text("The receiver must remain open. Android sends through its system-approved foreground capture service. Desktop browsers show their own screen picker. There is no silent capture, microphone capture or general iOS background server.").font(.footnote).foregroundStyle(.secondary) }
            Section { NavigationLink("Screen-sharing guide") { DocumentView(document: .screenSharing) } }
        }.navigationTitle("Screen sharing").navigationBarTitleDisplayMode(.inline)
    }
}

struct RecordingsView: View {
    @EnvironmentObject private var screen: ScreenSession
    @State private var selected: URL?
    @State private var deletion: URL?
    var body: some View {
        List {
            Section { Text("Screen video only, saved locally and excluded from backup by Still. Share to Files or another destination when you choose. Local Wipe deletes these recordings.").font(.footnote).foregroundStyle(.secondary) }
            if screen.recordings.isEmpty { ContentUnavailableView("No recordings yet", systemImage: "record.circle", description: Text("A sender must allow recording before you start.")) }
            ForEach(screen.recordings, id: \.self) { file in
                VStack(alignment: .leading, spacing: 12) {
                    Button { selected = file } label: { Label(file.deletingPathExtension().lastPathComponent, systemImage: "play.rectangle").lineLimit(2) }
                    HStack { ShareLink(item: file) { Label("Share", systemImage: "square.and.arrow.up") }; Spacer(); Button("Delete", role: .destructive) { deletion = file } }.font(.caption)
                }.padding(.vertical, 8)
            }
        }.navigationTitle("Recordings").navigationBarTitleDisplayMode(.inline).onAppear { screen.refreshRecordings() }
            .sheet(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) { if let file = selected { RecordingPreview(url: file) } }
            .confirmationDialog("Delete this recording?", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }), titleVisibility: .visible) { Button("Delete recording", role: .destructive) { if let deletion { screen.deleteRecording(deletion) }; deletion = nil } }
    }
}
private struct RecordingPreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    init(url: URL) { _player = State(initialValue: AVPlayer(url: url)) }
    var body: some View { NavigationStack { VideoPlayer(player: player).onDisappear { player.pause(); player.replaceCurrentItem(with: nil) }.navigationTitle("Recording").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } } } }
}
private struct SharingQRCode: View {
    let text: String
    var body: some View {
        Group { if let image { Image(uiImage: image).interpolation(.none).resizable().scaledToFit().padding(16).background(.white, in: RoundedRectangle(cornerRadius: 22)) } }.accessibilityLabel("Screen-sharing QR code. Use Share screen invitation for an accessible link.")
    }
    private var image: UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(text.utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), let result = CIContext().createCGImage(output, from: output.extent) else { return nil }; return UIImage(cgImage: result)
    }
}
