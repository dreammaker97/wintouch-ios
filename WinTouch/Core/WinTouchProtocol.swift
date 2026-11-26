import Foundation
import UIKit

public struct ImeDiff: Equatable {
    public let backspaces: Int
    public let insertText: String

    public init(backspaces: Int, insertText: String) {
        self.backspaces = backspaces
        self.insertText = insertText
    }
}

public struct ParsedConnectionURL: Equatable {
    public let host: String
    public let port: Int
    public let pin: String

    public init(host: String, port: Int, pin: String) {
        self.host = host
        self.port = port
        self.pin = pin
    }
}

public enum LandscapeLockMode: String, CaseIterable, Identifiable {
    case leftNotch = "cw"
    case rightNotch = "ccw"
    case both = "both"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .leftNotch: return "Tai thỏ Trái"
        case .rightNotch: return "Tai thỏ Phải"
        case .both: return "2 chiều ngang"
        }
    }

    public var interfaceMask: UIInterfaceOrientationMask {
        switch self {
        case .leftNotch: return .landscapeRight
        case .rightNotch: return .landscapeLeft
        case .both: return .landscape
        }
    }
}

public enum ThemeMode: String, CaseIterable, Identifiable {
    case system = "system"
    case dark = "dark"
    case light = "light"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "Hệ thống"
        case .dark: return "Tối"
        case .light: return "Sáng"
        }
    }
}

public enum ModifierState: Equatable {
    case once
    case locked
}

public enum WinTouchProtocol {
    /// Longest-common-prefix diff for Vietnamese Telex/VNI live IME typing.
    public static func computeImeDiff(prev: String, next: String) -> ImeDiff {
        let prevChars = Array(prev)
        let nextChars = Array(next)
        let minCount = min(prevChars.count, nextChars.count)
        var lcp = 0
        while lcp < minCount && prevChars[lcp] == nextChars[lcp] {
            lcp += 1
        }
        let bs = prevChars.count - lcp
        let ins = String(nextChars[lcp...])
        return ImeDiff(backspaces: bs, insertText: ins)
    }

    /// Parses QR URL of the form http://<host>:<port>/?pin=123456
    public static func parseConnectionURL(_ raw: String) -> ParsedConnectionURL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comps = URLComponents(string: trimmed),
              let host = comps.host, !host.isEmpty else {
            return nil
        }
        let port = comps.port ?? 8765
        guard port >= 1024 && port <= 65535 else {
            return nil
        }
        let pin = comps.queryItems?.first(where: { $0.name.lowercased() == "pin" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard pin.count == 6 && pin.allSatisfy({ $0.isNumber }) else {
            return nil
        }
        return ParsedConnectionURL(host: host, port: port, pin: pin)
    }

    public static func encodeJSON(_ dict: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(dict),
              let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }
}
