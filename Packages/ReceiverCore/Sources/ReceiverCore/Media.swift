import Foundation

public enum MediaError: String, Error, LocalizedError {
    case invalidURL = "Enter a complete HTTPS video URL."
    case unsupported = "Use a YouTube video link or a direct MP4, MOV, M4V, MP3, M4A or HLS stream."
    public var errorDescription: String? { rawValue }
}

public struct Media: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case youtube(String), stream }
    public let id: UUID
    public let url: URL
    public let kind: Kind
    public let title: String
    public init(_ input: String, title: String? = nil) throws {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.utf8.count <= 4096, let parts = URLComponents(string: text),
              parts.scheme?.lowercased() == "https", let host = parts.host?.lowercased(),
              !host.isEmpty, parts.user == nil, parts.password == nil,
              let url = parts.url else { throw MediaError.invalidURL }
        let youtubeHosts = ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be", "www.youtu.be"]
        let kind: Kind
        if youtubeHosts.contains(host) {
            let path = url.pathComponents.filter { $0 != "/" }
            let candidate: String?
            if host.hasSuffix("youtu.be") { candidate = path.first }
            else if ["shorts", "embed", "live"].contains(path.first ?? "") { candidate = path.dropFirst().first }
            else if url.path == "/watch" { candidate = parts.queryItems?.first(where: { $0.name == "v" })?.value }
            else { candidate = nil }
            guard let video = candidate, video.count == 11,
                  video.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-").contains($0) }) else { throw MediaError.unsupported }
            kind = .youtube(video)
        } else {
            guard ["mp4", "mov", "m4v", "m3u8", "mp3", "m4a"].contains(url.pathExtension.lowercased()) else { throw MediaError.unsupported }
            kind = .stream
        }
        self.id = UUID(); self.url = url; self.kind = kind
        let cleaned = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = String((cleaned?.isEmpty == false ? cleaned! : (kind == .stream ? url.lastPathComponent : "YouTube video")).prefix(120))
    }
    public var source: String { if case .youtube = kind { return "YouTube" }; return url.host ?? "Stream" }
}
