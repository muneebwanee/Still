import SwiftUI
import WebRTC
import AVFoundation

@MainActor final class ScreenSession: NSObject, ObservableObject {
    enum State: Equatable { case stopped, connecting, waiting, viewing, reconnecting, failed(String) }
    @Published private(set) var state: State = .stopped
    @Published private(set) var invitation: URL?
    @Published private(set) var track: RTCVideoTrack?
    @Published private(set) var recordingAllowed = false
    @Published private(set) var isRecording = false
    @Published private(set) var finishingRecording = false
    @Published var notice: String?
    @Published private(set) var recordings: [URL] = []
    private static let sharedFactory: RTCPeerConnectionFactory = { RTCInitializeSSL(); return RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(), decoderFactory: RTCDefaultVideoDecoderFactory()) }()
    private lazy var factory = ScreenSession.sharedFactory
    private var socket: URLSessionWebSocketTask?
    private var peer: RTCPeerConnection?
    private var bridge: PeerBridge?
    private var ice: [RTCIceServer] = []
    private var pending: [RTCIceCandidate] = []
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var server: URL?
    private var room = "", owner = "", invite = ""
    private var attempt = 0
    private var generation = UUID()
    private var recorder: ScreenRecorder?
    private var finishWaiters: [CheckedContinuation<Void, Never>] = []
    let playback: Playback
    let receiver: Receiver
    var isActive: Bool { switch state { case .stopped, .failed: return false; default: return true } }
    init(playback: Playback, receiver: Receiver) { self.playback = playback; self.receiver = receiver; super.init()
        if let folder = try? Self.recordingsDirectory(), let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: []) { for file in files where file.pathExtension == "partial" { try? FileManager.default.removeItem(at: file) } }
        refreshRecordings() }
    func start() {
        stop()
        guard let text = UserDefaults.standard.string(forKey: "sharingServer"), let parts = URLComponents(string: text), parts.scheme == "https", parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil, let host = parts.host, !host.isEmpty, (parts.path.isEmpty || parts.path == "/"), let url = parts.url else { state = .failed("Screen sharing needs a valid HTTPS connection-service address in Settings → Screen sharing."); return }
        receiver.stop(); playback.stop(); server = url
        room = Self.token(); owner = Self.token(); invite = Self.token(); attempt = 0
        notice = nil; state = .connecting; generation = UUID(); connect()
    }
    private static func token() -> String { UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() }
    private func connect() {
        guard let server else { return }
        receiveTask?.cancel(); pingTask?.cancel(); socket?.cancel(with: .goingAway, reason: nil)
        var parts = URLComponents(url: server, resolvingAgainstBaseURL: false)!
        parts.scheme = "wss"; parts.path = "/signal"
        let socket = URLSession.shared.webSocketTask(with: parts.url!); self.socket = socket
        let current = generation; socket.resume()
        receiveTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.send(["type":"create","room":self.room,"owner":self.owner,"invite":self.invite], through: socket)
                while !Task.isCancelled {
                    let message = try await socket.receive()
                    guard self.generation == current, self.socket === socket else { return }
                    let data: Data
                    switch message { case .string(let text): data = Data(text.utf8); case .data(let bytes): data = bytes; @unknown default: continue }
                    guard data.count <= 131072, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    try await self.handle(object, generation: current)
                }
            } catch { if self.generation == current, self.socket === socket, !Task.isCancelled { self.reconnect() } }
        }
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(15)); try await socket.sendPing() }
                catch { if !Task.isCancelled, self?.socket === socket { self?.reconnect() }; return }
            }
        }
    }
    private func reconnect() {
        guard server != nil, reconnectTask == nil else { return }
        if attempt >= 6 { stop(); state = .failed("Connection lost. Start a new invitation when your network is ready."); return }
        state = .reconnecting; closePeer(); socket?.cancel(with: .goingAway, reason: nil); receiveTask?.cancel(); pingTask?.cancel()
        let delay = min(10, pow(2, Double(attempt))); attempt += 1
        reconnectTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self else { return }; self.reconnectTask = nil; self.connect()
        }
    }
    private func handle(_ message: [String: Any], generation current: UUID) async throws {
        switch message["type"] as? String {
        case "ready":
            ice = (message["iceServers"] as? [[String: Any]] ?? []).compactMap { entry in
                guard let urls = entry["urls"] as? [String] else { return nil }
                return RTCIceServer(urlStrings: urls, username: entry["username"] as? String, credential: entry["credential"] as? String)
            }
            var parts = URLComponents(url: server!, resolvingAgainstBaseURL: false)!
            parts.path = "/"; parts.fragment = "room=\(room)&invite=\(invite)"; invitation = parts.url; state = .waiting
        case "peer-joined": recordingAllowed = message["allowRecording"] as? Bool ?? false; closePeer(); preparePeer()
        case "offer":
            guard let sdp = message["sdp"] as? String else { return }
            if peer == nil { preparePeer() }; guard let peer else { return }
            try await peer.acceptScreenOffer(RTCSessionDescription(type: .offer, sdp: sdp))
            guard generation == current, self.peer === peer else { return }
            let candidates = pending; pending.removeAll()
            for candidate in candidates { try await peer.addScreenCandidate(candidate); guard generation == current, self.peer === peer else { return } }
            let answer = try await peer.makeScreenAnswer()
            guard generation == current, self.peer === peer else { return }
            try await peer.acceptScreenAnswer(answer)
            guard generation == current, self.peer === peer else { return }
            try await send(["type":"answer","sdp":answer.sdp])
        case "candidate":
            guard let candidate = message["candidate"] as? String, let line = message["sdpMLineIndex"] as? Int32 else { return }
            let item = RTCIceCandidate(sdp: candidate, sdpMLineIndex: line, sdpMid: message["sdpMid"] as? String)
            if let peer, peer.remoteDescription != nil { try await peer.addScreenCandidate(item) } else if pending.count < 256 { pending.append(item) }
        case "peer-left": closePeer(); recordingAllowed = false; state = .waiting; notice = "The sender stopped sharing. You can invite another screen."
        case "ended": stop(); notice = "This screen-sharing session ended."
        case "error": let message = message["message"] as? String ?? "Connection service rejected this session."; stop(); state = .failed(message)
        default: break
        }
    }
    private func preparePeer() {
        let config = RTCConfiguration(); config.sdpSemantics = .unifiedPlan; config.iceServers = ice
        let bridge = PeerBridge(); self.bridge = bridge
        bridge.onTrack = { [weak self] connection, track in Task { @MainActor in guard let self, self.peer === connection else { return }; self.track = track } }
        bridge.onCandidate = { [weak self] connection, candidate in Task { @MainActor in guard let self, self.peer === connection else { return }; try? await self.send(["type":"candidate","candidate":candidate.sdp,"sdpMid":candidate.sdpMid as Any? ?? NSNull(),"sdpMLineIndex":candidate.sdpMLineIndex]) } }
        bridge.onState = { [weak self] connection, state in Task { @MainActor in
            guard let self, self.peer === connection else { return }
            if state == .connected { self.state = .viewing; self.attempt = 0 }
            else if state == .disconnected { self.state = .reconnecting }
            else if state == .failed { self.reconnect() }
        } }
        peer = factory.peerConnection(with: config, constraints: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil), delegate: bridge)
    }
    private func send(_ message: [String: Any], through socket: URLSessionWebSocketTask? = nil) async throws {
        guard let socket = socket ?? self.socket else { return }
        let data = try JSONSerialization.data(withJSONObject: message)
        try await socket.send(.data(data))
    }
    private func closePeer() { stopRecording(); track = nil; peer?.delegate = nil; peer?.close(); peer = nil; bridge = nil; pending.removeAll() }
    func stop() {
        generation = UUID(); reconnectTask?.cancel(); reconnectTask = nil
        // Closing the owner's socket leaves a short reconnect grace; explicit stop revokes the room via `end`.
        if let socket { let bytes = try? JSONSerialization.data(withJSONObject: ["type":"end"]); if let bytes { socket.send(.data(bytes)) { _ in socket.cancel(with: .normalClosure, reason: nil) } } else { socket.cancel(with: .normalClosure, reason: nil) } }
        receiveTask?.cancel(); receiveTask = nil; pingTask?.cancel(); pingTask = nil; socket = nil
        closePeer(); server = nil; room = ""; owner = ""; invite = ""; invitation = nil; recordingAllowed = false; state = .stopped
    }
    static func recordingsDirectory() throws -> URL {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var resource = URLResourceValues(); resource.isExcludedFromBackup = true; var result = folder; try result.setResourceValues(resource)
        return folder
    }
    func startRecording() {
        guard recordingAllowed, !isRecording, !finishingRecording, let track, state == .viewing else { return }
        do {
            let file = try Self.recordingsDirectory().appendingPathComponent(".\(UUID().uuidString).partial")
            let recorder = ScreenRecorder(); self.recorder = recorder
            recorder.onFailure = { [weak self] message in Task { @MainActor in self?.notice = message; self?.stopRecording() } }
            recorder.start(at: file); track.add(recorder); isRecording = true
            Task { try? await send(["type":"recording","active":true]) }
        } catch { notice = "Recording could not start: \(error.localizedDescription)" }
    }
    func stopRecording() {
        guard let recorder, !finishingRecording else { return }
        self.recorder = nil; track?.remove(recorder); isRecording = false; finishingRecording = true
        Task { try? await send(["type":"recording","active":false]) }
        let lease = RecordingFinishLease()
        recorder.finish { [weak self] result in Task { @MainActor in
            guard let self else { lease.end(); return }
            switch result {
            case .success(let temporary):
                do { let final = temporary.deletingLastPathComponent().appendingPathComponent("Still-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(6)).mp4"); try FileManager.default.moveItem(at: temporary, to: final); self.notice = "Recording saved on this device." }
                catch { self.notice = "The recording could not be saved."; try? FileManager.default.removeItem(at: temporary) }
            case .failure(let error): self.notice = error.localizedDescription
            }
            self.finishingRecording = false; self.refreshRecordings()
            lease.end()
            let waiters = self.finishWaiters; self.finishWaiters.removeAll(); for waiter in waiters { waiter.resume() }
        } }
    }
    func waitForRecording() async { if finishingRecording { await withCheckedContinuation { finishWaiters.append($0) } } }
    func refreshRecordings() { recordings = ((try? Self.recordingsDirectory()).flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) } ?? []).filter { $0.pathExtension == "mp4" }.sorted { $0.lastPathComponent > $1.lastPathComponent } }
    func deleteRecording(_ file: URL) { guard recordings.contains(file) else { return }; do { try FileManager.default.removeItem(at: file); refreshRecordings() } catch { notice = "Could not delete this recording." } }
    func wipeRecordings() throws { let folder = try Self.recordingsDirectory(); try FileManager.default.removeItem(at: folder); refreshRecordings() }
}

private final class PeerBridge: NSObject, RTCPeerConnectionDelegate {
    var onTrack: ((RTCPeerConnection, RTCVideoTrack) -> Void)?
    var onCandidate: ((RTCPeerConnection, RTCIceCandidate) -> Void)?
    var onState: ((RTCPeerConnection, RTCPeerConnectionState) -> Void)?
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) { onCandidate?(peerConnection,candidate) }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) { onState?(peerConnection,newState) }
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) { if let audio = rtpReceiver.track as? RTCAudioTrack { audio.isEnabled = false }; if let video = rtpReceiver.track as? RTCVideoTrack { onTrack?(peerConnection,video) } }
}

@MainActor private final class RecordingFinishLease {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    init() { identifier = UIApplication.shared.beginBackgroundTask(withName: "Finish screen recording") { [weak self] in Task { @MainActor in self?.end() } } }
    func end() { if identifier != .invalid { UIApplication.shared.endBackgroundTask(identifier); identifier = .invalid } }
}

private extension RTCPeerConnection {
    func acceptScreenOffer(_ description: RTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setRemoteDescription(description) { error in if let error { continuation.resume(throwing: error) } else { continuation.resume() } }
        }
    }
    func acceptScreenAnswer(_ description: RTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setLocalDescription(description) { error in if let error { continuation.resume(throwing: error) } else { continuation.resume() } }
        }
    }
    func makeScreenAnswer() async throws -> RTCSessionDescription {
        try await withCheckedThrowingContinuation { continuation in
            answer(for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)) { description, error in
                if let error { continuation.resume(throwing: error) }
                else if let description { continuation.resume(returning: description) }
                else { continuation.resume(throwing: NSError(domain: "Still.ScreenSharing", code: 1, userInfo: [NSLocalizedDescriptionKey:"No screen connection answer was created."])) }
            }
        }
    }
    func addScreenCandidate(_ candidate: RTCIceCandidate) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            add(candidate) { error in if let error { continuation.resume(throwing: error) } else { continuation.resume() } }
        }
    }
}
