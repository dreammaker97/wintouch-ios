import XCTest
@testable import WinTouch

final class WinTouchTests: XCTestCase {
    func testImeDiffVietnameseTelex() {
        XCTAssertEqual(
            WinTouchProtocol.computeImeDiff(prev: " ", next: " a"),
            ImeDiff(backspaces: 0, insertText: "a")
        )
        XCTAssertEqual(
            WinTouchProtocol.computeImeDiff(prev: " tiee", next: " tiê"),
            ImeDiff(backspaces: 2, insertText: "ê")
        )
        XCTAssertEqual(
            WinTouchProtocol.computeImeDiff(prev: " tiêng", next: " tiếng"),
            ImeDiff(backspaces: 3, insertText: "ếng")
        )
        XCTAssertEqual(
            WinTouchProtocol.computeImeDiff(prev: " tiếng", next: " tiến"),
            ImeDiff(backspaces: 1, insertText: "")
        )
        XCTAssertEqual(
            WinTouchProtocol.computeImeDiff(prev: " hi", next: " hi 🚀"),
            ImeDiff(backspaces: 0, insertText: " 🚀")
        )
    }

    func testParseConnectionURL() {
        let parsed = WinTouchProtocol.parseConnectionURL("http://192.168.0.10:8765/?pin=123456")
        XCTAssertEqual(parsed, ParsedConnectionURL(host: "192.168.0.10", port: 8765, pin: "123456"))

        let defaultPort = WinTouchProtocol.parseConnectionURL("http://192.168.1.100/?pin=000999")
        XCTAssertEqual(defaultPort, ParsedConnectionURL(host: "192.168.1.100", port: 8765, pin: "000999"))

        XCTAssertNil(WinTouchProtocol.parseConnectionURL("http://192.168.0.10:8765/?pin=12345"))
        XCTAssertNil(WinTouchProtocol.parseConnectionURL("not-a-url"))
    }

    func testLandscapeLockMasks() {
        XCTAssertEqual(LandscapeLockMode.leftNotch.interfaceMask, .landscapeRight)
        XCTAssertEqual(LandscapeLockMode.rightNotch.interfaceMask, .landscapeLeft)
        XCTAssertEqual(LandscapeLockMode.both.interfaceMask, .landscape)
    }

    func testEncodeJSON() {
        let json = WinTouchProtocol.encodeJSON(["t": "mb", "b": "left", "a": "click"])
        XCTAssertNotNil(json)
        XCTAssertTrue(json?.contains("\"t\":\"mb\"") == true)
    }
}
