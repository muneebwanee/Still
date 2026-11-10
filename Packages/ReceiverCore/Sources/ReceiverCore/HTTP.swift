import Foundation

public struct HTTPRequest: Sendable {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public let body: Data
}
public enum HTTPParseError: Error { case malformed, tooLarge }

/// One request per connection. No chunking, pipelining, or ambiguous framing.
public enum HTTPParser {
    public static let maximumSize = 16_384
    public static func parse(_ data: Data) throws -> HTTPRequest? {
        guard data.count <= maximumSize else { throw HTTPParseError.tooLarge }
        guard let boundary = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        guard let head = String(data: data[..<boundary.lowerBound], encoding: .utf8) else { throw HTTPParseError.malformed }
        let lines = head.components(separatedBy: "\r\n")
        let start = (lines.first ?? "").split(separator: " ")
        guard start.count == 3, start[2] == "HTTP/1.1", ["GET", "POST"].contains(String(start[0])), start[1].hasPrefix("/"), !start[1].hasPrefix("//") else { throw HTTPParseError.malformed }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":"), !line.hasPrefix(" "), !line.hasPrefix("\t") else { throw HTTPParseError.malformed }
            let name = String(line[..<colon]).lowercased()
            guard !name.isEmpty, name.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }), headers[name] == nil else { throw HTTPParseError.malformed }
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard headers["host"] != nil, headers["transfer-encoding"] == nil else { throw HTTPParseError.malformed }
        let lengthText = headers["content-length"] ?? "0"
        guard !lengthText.isEmpty, lengthText.utf8.allSatisfy({ (48...57).contains($0) }), let length = Int(lengthText), length <= maximumSize - boundary.upperBound else { throw HTTPParseError.tooLarge }
        let count = data.count - boundary.upperBound
        guard count >= length else { return nil }
        guard count == length else { throw HTTPParseError.malformed }
        return HTTPRequest(method: String(start[0]), path: String(start[1]), headers: headers, body: Data(data[boundary.upperBound...]))
    }
}

public struct RemoteCommand: Decodable, Sendable {
    public enum Action: String, Decodable, Sendable { case load, enqueue, play, pause, stop, next, seek, volume }
    public let action: Action
    public let url: String?
    public let title: String?
    public let value: Double?
}
