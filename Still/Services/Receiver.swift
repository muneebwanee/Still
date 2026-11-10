import Foundation
import Darwin
import Network
import UIKit
import ReceiverCore
import Combine

@MainActor final class Receiver: ObservableObject {
    enum State: Equatable { case stopped, starting, running, failed(String) }
    @Published private(set) var state: State = .stopped
    @Published private(set) var address: String?
    @Published private(set) var token = ""
    @Published private(set) var lastActivity: Date?
    private var listener: NWListener?
    private var monitor: NWPathMonitor?
    private var connections: [UUID: NWConnection] = [:]
    private var buffers: [UUID: Data] = [:]
    private var deadlines: [UUID: DispatchWorkItem] = [:]
    private let playback: Playback
    private(set) var name = "Still"
    private let port: UInt16 = 8942
    var pairingURL: URL? { guard state == .running, let address else { return nil }; return URL(string: "http://\(address):\(port)/#\(token)") }
    init(playback: Playback) { self.playback = playback }
    func start(name: String) {
        guard state != .running, state != .starting else { return }
        self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        if self.name.isEmpty { self.name = "Still" }
        state = .starting; token = UUID().uuidString.replacingOccurrences(of: "-", with: ""); address = Self.wifiAddress()
        do {
            let parameters = NWParameters.tcp
            parameters.requiredInterfaceType = .wifi
            parameters.includePeerToPeer = false
            let server = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            server.service = .init(name: self.name, type: "_stillcast._tcp")
            server.stateUpdateHandler = { [weak self] update in
                Task { @MainActor in
                    guard let self, self.listener === server else { return }
                    switch update {
                    case .ready:
                        self.address = Self.wifiAddress()
                        if self.address == nil { self.fail("Connect to Wi-Fi, then start again.") }
                        else { self.state = .running }
                    case .failed(let error): self.fail("Receiver unavailable: \(error.localizedDescription). Check Local Network access in Settings and your Wi-Fi connection.")
                    default: break
                    }
                }
            }
            server.newConnectionHandler = { [weak self] connection in Task { @MainActor in self?.accept(connection) } }
            listener = server; server.start(queue: .main)
            let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
            monitor.pathUpdateHandler = { [weak self, weak monitor] path in
                Task { @MainActor in
                    guard let self, let monitor, self.monitor === monitor, self.listener != nil else { return }
                    let ip = Self.wifiAddress()
                    if path.status != .satisfied || (self.state == .running && self.address != ip) { self.fail("Wi-Fi changed or disconnected. Start again to create a new pairing link.") }
                }
            }
            self.monitor = monitor; monitor.start(queue: .main)
        } catch { fail(error.localizedDescription) }
    }
    func stop() {
        listener?.stateUpdateHandler = nil; listener?.newConnectionHandler = nil; listener?.cancel(); listener = nil; monitor?.cancel(); monitor = nil
        for connection in connections.values { connection.cancel() }
        for deadline in deadlines.values { deadline.cancel() }
        connections.removeAll(); buffers.removeAll(); deadlines.removeAll()
        address = nil; token = ""; state = .stopped
    }
    var queueOnly: Bool { UserDefaults.standard.bool(forKey: "queueOnly") }
    func clearActivity() { lastActivity = nil }
    func disconnectRemotes() { let previousName = name; stop(); start(name: previousName) }
    private func fail(_ message: String) { stop(); state = .failed(message) }
    private func accept(_ connection: NWConnection) {
        guard connections.count < 8, state == .running else { connection.cancel(); return }
        let id = UUID(); connections[id] = connection; buffers[id] = Data()
        let timeout = DispatchWorkItem { [weak self] in self?.close(id) }
        deadlines[id] = timeout; DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout)
        connection.start(queue: .main); receive(id)
    }
    private func receive(_ id: UUID) {
        connections[id]?.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, ended, error in
            Task { @MainActor in
                guard let self, self.connections[id] != nil else { return }
                if let data { self.buffers[id, default: Data()].append(data) }
                do {
                    if let request = try HTTPParser.parse(self.buffers[id] ?? Data()) { self.route(request, id: id); return }
                    if ended || error != nil { self.close(id) } else { self.receive(id) }
                } catch { self.reply(id, status: 400, json: ["error": "Invalid or oversized request."]) }
            }
        }
    }
    private func route(_ request: HTTPRequest, id: UUID) {
        guard let address, request.headers["host"] == "\(address):\(port)" else { reply(id, status: 403, json: ["error": "Invalid receiver address."]); return }
        if let origin = request.headers["origin"], origin != "http://\(address):\(port)" { reply(id, status: 403, json: ["error": "Cross-origin requests are not allowed."]); return }
        if request.method == "GET", request.path == "/" {
            guard let url = Bundle.main.url(forResource: "remote", withExtension: "html"), let data = try? Data(contentsOf: url) else { reply(id, status: 500, json: ["error": "Remote unavailable."]); return }
            send(id, status: 200, type: "text/html; charset=utf-8", data: data); return
        }
        guard request.headers["authorization"] == "Bearer \(token)", !token.isEmpty else { reply(id, status: 401, json: ["error": "Pair again using the QR code on your receiver."]); return }
        if request.method == "GET", request.path == "/api/state" {
            reply(id, status: 200, json: ["theme": UserDefaults.standard.string(forKey: "theme") ?? "Graphite", "queueOnly": queueOnly, "name": name, "title": playback.current?.title ?? "Ready to receive", "source": playback.current?.source ?? "", "playing": playback.isPlaying, "buffering": playback.isBuffering, "position": playback.position, "duration": playback.duration, "volume": playback.volume, "queue": playback.queue.map(\.title), "error": playback.error ?? ""]); return
        }
        guard request.method == "POST", request.path == "/api/command", request.headers["content-type"]?.lowercased().hasPrefix("application/json") == true else { reply(id, status: 404, json: ["error": "Unknown request."]); return }
        do {
            let command = try JSONDecoder().decode(RemoteCommand.self, from: request.body)
            let policy: RemoteAccessPolicy = queueOnly ? .queueOnly : .fullControl
            guard policy.allows(command.action) else { throw CommandError.queueOnly }
            switch command.action {
            case .load, .enqueue:
                let media = try Media(command.url ?? "", title: command.title)
                if command.action == .load { try playback.load(media) } else { try playback.enqueue(media, startIfIdle: !queueOnly) }
            case .play: playback.play()
            case .pause: playback.pause()
            case .stop: playback.stop()
            case .next: playback.next()
            case .seek:
                guard let value = command.value, value.isFinite, value >= 0 else { throw CommandError.invalidValue }
                playback.seek(value)
            case .volume:
                guard let value = command.value, value.isFinite, (0...1).contains(value) else { throw CommandError.invalidValue }
                playback.volume = value
            }
            lastActivity = Date(); reply(id, status: 200, json: ["ok": true])
        } catch { reply(id, status: 422, json: ["error": (error as? LocalizedError)?.errorDescription ?? "Invalid command."]) }
    }
    private func reply(_ id: UUID, status: Int, json: [String: Any]) { send(id, status: status, type: "application/json", data: (try? JSONSerialization.data(withJSONObject: json)) ?? Data("{}".utf8)) }
    private func send(_ id: UUID, status: Int, type: String, data: Data) {
        let reason = [200: "OK", 400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found", 422: "Unprocessable Content", 500: "Internal Server Error"][status] ?? "Error"
        let headers = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(type)\r\nContent-Length: \(data.count)\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\nContent-Security-Policy: default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'\r\n\r\n"
        connections[id]?.send(content: Data(headers.utf8) + data, completion: .contentProcessed { [weak self] _ in Task { @MainActor in self?.close(id) } })
    }
    private func close(_ id: UUID) { deadlines.removeValue(forKey: id)?.cancel(); connections.removeValue(forKey: id)?.cancel(); buffers.removeValue(forKey: id) }
    private static func wifiAddress() -> String? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let item = cursor {
            let value = item.pointee
            if String(cString: value.ifa_name) == "en0", let address = value.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let capacity = socklen_t(host.count)
                if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, capacity, nil, 0, NI_NUMERICHOST) == 0 { return String(cString: host) }
            }
            cursor = value.ifa_next
        }
        return nil
    }
}
private enum CommandError: LocalizedError {
    case invalidValue, queueOnly
    var errorDescription: String? {
        switch self {
        case .invalidValue: return "Value is out of range."
        case .queueOnly: return "This is a queue-only session. You can add videos; playback stays under the receiver’s control."
        }
    }
}
