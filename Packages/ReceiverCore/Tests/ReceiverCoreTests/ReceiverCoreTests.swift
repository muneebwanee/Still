import XCTest
@testable import ReceiverCore

final class ReceiverCoreTests: XCTestCase {
    func testQueueOnlyIsEnforcedForEveryCommand() {
        let transport: [RemoteCommand.Action] = [.load, .play, .pause, .stop, .next, .seek, .volume]
        for action in transport { XCTAssertFalse(RemoteAccessPolicy.queueOnly.allows(action)); XCTAssertTrue(RemoteAccessPolicy.fullControl.allows(action)) }
        XCTAssertTrue(RemoteAccessPolicy.queueOnly.allows(.enqueue))
    }
    func testUnsupportedSavedSpeedFallsBackToNormal() {
        for value in [0, -1, 100, Double.nan, Double.infinity] { XCTAssertEqual(PlaybackChoices.validSpeed(value), 1) }
        for value in PlaybackChoices.speeds { XCTAssertEqual(PlaybackChoices.validSpeed(value), value) }
    }
    func testYouTubeForms() throws {
        for link in ["https://youtu.be/dQw4w9WgXcQ?t=3", "https://www.youtube.com/watch?v=dQw4w9WgXcQ", "https://m.youtube.com/shorts/dQw4w9WgXcQ", "https://youtube.com/live/dQw4w9WgXcQ"] {
            XCTAssertEqual(try Media(link).kind, .youtube("dQw4w9WgXcQ"))
        }
    }
    func testRejectsSpoofedAndUnsafeLinks() {
        for link in ["javascript:alert(1)", "http://example.com/a.mp4", "https://youtube.com.evil.org/watch?v=dQw4w9WgXcQ", "https://youtube.com/watch?v=bad", "https://user:pass@example.com/a.mp4", "https://example.com/", "https://youtu.be/<script>123"] {
            XCTAssertThrowsError(try Media(link), link)
        }
    }
    func testStreamQueryAndTitle() throws {
        let media = try Media("https://cdn.example.com/live.m3u8?token=abc", title: String(repeating: "a", count: 200))
        XCTAssertEqual(media.kind, .stream)
        XCTAssertEqual(media.title.count, 120)
        XCTAssertEqual(media.url.query, "token=abc")
    }
    func testPartialRequest() throws {
        XCTAssertNil(try HTTPParser.parse(Data("POST /api/command HTTP/1.1\r\nHost: device\r\nContent-Length: 4\r\n\r\nab".utf8)))
        let request = try XCTUnwrap(HTTPParser.parse(Data("POST /api/command HTTP/1.1\r\nHost: device\r\nContent-Length: 4\r\n\r\nabcd".utf8)))
        XCTAssertEqual(String(data: request.body, encoding: .utf8), "abcd")
    }
    func testRejectsAmbiguousFraming() {
        for headers in ["Host: a\r\nHost: b", "Host: a\r\nTransfer-Encoding: chunked", "Host: a\r\nContent-Length: -1", "Host: a\r\nContent-Length: 1\r\nContent-Length: 2", "Host: a\r\n Bad: value"] {
            XCTAssertThrowsError(try HTTPParser.parse(Data("POST / HTTP/1.1\r\n\(headers)\r\n\r\n".utf8)))
        }
        XCTAssertThrowsError(try HTTPParser.parse(Data(repeating: 65, count: 16_385)))
        XCTAssertThrowsError(try HTTPParser.parse(Data("GET / HTTP/1.1\r\nHost: a\r\n\r\nextra".utf8)))
    }
    func testEveryFragmentBoundary() throws {
        let packet = Data("POST /api/command HTTP/1.1\r\nHost: a\r\nContent-Length: 2\r\n\r\n{}".utf8)
        for n in 0..<packet.count { XCTAssertNil(try HTTPParser.parse(packet.prefix(n))) }
        XCTAssertNotNil(try HTTPParser.parse(packet))
    }
}
