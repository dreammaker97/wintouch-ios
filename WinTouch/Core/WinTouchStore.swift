import AudioToolbox
import Foundation
import SwiftUI
import UIKit

public final class OrientationAppDelegate: NSObject, UIApplicationDelegate {
    public static var orientationMask: UIInterfaceOrientationMask = .landscapeRight

    public func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return OrientationAppDelegate.orientationMask
    }
}

public enum ConnectionStatus: Equatable {
    case offline(String)
    case connecting(String)
    case online(Int?)

    public var label: String {
        switch self {
        case .offline(let msg): return msg
        case .connecting(let msg): return msg
        case .online(let rtt):
            if let ms = rtt {
                return "Đã kết nối · \(ms)ms"
            }
            return "Đã kết nối"
        }
    }

    public var color: Color {
        switch self {
        case .offline: return Color(red: 0.96, green: 0.25, blue: 0.37)
        case .connecting: return Color(red: 0.96, green: 0.62, blue: 0.04)
        case .online: return Color(red: 0.20, green: 0.83, blue: 0.60)
        }
    }
}

public enum MainControlTab: String, CaseIterable {
    case trackpad
    case keyboard
}

@MainActor
public final class WinTouchStore: ObservableObject {
    // UserDefaults Keys
    private enum Keys {
        static let host = "wt.host"
        static let port = "wt.port"
        static let token = "wt.token"
        static let deviceId = "wt.deviceId"
        static let sensitivity = "wt.sensitivity"
        static let accel = "wt.accel"
        static let naturalScroll = "wt.naturalScroll"
        static let haptic = "wt.haptic"
        static let sound = "wt.sound"
        static let wakeLock = "wt.wakeLock"
        static let composeMode = "wt.composeMode"
        static let landscapeMode = "wt.landscapeMode"
        static let themeMode = "wt.themeMode"
    }

    // Connection State
    @Published public var host: String
    @Published public var port: Int
    @Published public var authToken: String
    @Published public var deviceId: String
    @Published public var status: ConnectionStatus = .offline("Chưa kết nối")

    // UI State
    @Published public var activeTab: MainControlTab = .trackpad
    @Published public var showIosKeyboard: Bool = false
    @Published public var showNumpad: Bool = false
    @Published public var dragLocked: Bool = false
    @Published public var stickyMods: [String: ModifierState] = [:]

    // Modals
    @Published public var showConnectSheet: Bool = false
    @Published public var showQRScanner: Bool = false
    @Published public var showClipboardSheet: Bool = false
    @Published public var showPowerSheet: Bool = false
    @Published public var showSettingsSheet: Bool = false
    @Published public var clipboardText: String = ""
    @Published public var toastMessage: String?

    // Preferences
    @Published public var sensitivity: Double {
        didSet { UserDefaults.standard.set(sensitivity, forKey: Keys.sensitivity) }
    }
    @Published public var accelEnabled: Bool {
        didSet { UserDefaults.standard.set(accelEnabled, forKey: Keys.accel) }
    }
    @Published public var naturalScroll: Bool {
        didSet { UserDefaults.standard.set(naturalScroll, forKey: Keys.naturalScroll) }
    }
    @Published public var hapticEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticEnabled, forKey: Keys.haptic) }
    }
    @Published public var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: Keys.sound) }
    }
    @Published public var wakeLockEnabled: Bool {
        didSet {
            UserDefaults.standard.set(wakeLockEnabled, forKey: Keys.wakeLock)
            applyWakeLock()
        }
    }
    @Published public var composeMode: Bool {
        didSet { UserDefaults.standard.set(composeMode, forKey: Keys.composeMode) }
    }
    @Published public var landscapeMode: LandscapeLockMode {
        didSet {
            UserDefaults.standard.set(landscapeMode.rawValue, forKey: Keys.landscapeMode)
            applyOrientationLock()
        }
    }
    @Published public var themeMode: ThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: Keys.themeMode) }
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private var pingTimer: Timer?
    private var reconnectWorkItem: DispatchWorkItem?
    private var reconnectDelay: TimeInterval = 0.8
    private var lastModTap: [String: Date] = [:]
    private var toastWorkItem: DispatchWorkItem?
    private var isSocketOpened = false

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

    public init() {
        let ud = UserDefaults.standard
        self.host = ud.string(forKey: Keys.host) ?? ""
        let savedPort = ud.integer(forKey: Keys.port)
        self.port = (savedPort >= 1024 && savedPort <= 65535) ? savedPort : 8765
        self.authToken = ud.string(forKey: Keys.token) ?? ""

        if let existingDev = ud.string(forKey: Keys.deviceId), !existingDev.isEmpty {
            self.deviceId = existingDev
        } else {
            let prefix = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
            let suffix = String(UUID().uuidString.prefix(4)).uppercased()
            let generated = "\(prefix)-\(suffix)"
            ud.set(generated, forKey: Keys.deviceId)
            self.deviceId = generated
        }

        let sens = ud.object(forKey: Keys.sensitivity) as? Double ?? 1.6
        self.sensitivity = min(max(sens, 0.5), 4.0)
        self.accelEnabled = ud.object(forKey: Keys.accel) as? Bool ?? true
        self.naturalScroll = ud.object(forKey: Keys.naturalScroll) as? Bool ?? true
        self.hapticEnabled = ud.object(forKey: Keys.haptic) as? Bool ?? true
        self.soundEnabled = ud.object(forKey: Keys.sound) as? Bool ?? false
        self.wakeLockEnabled = ud.object(forKey: Keys.wakeLock) as? Bool ?? true
        self.composeMode = ud.object(forKey: Keys.composeMode) as? Bool ?? false

        let lmRaw = ud.string(forKey: Keys.landscapeMode) ?? LandscapeLockMode.leftNotch.rawValue
        self.landscapeMode = LandscapeLockMode(rawValue: lmRaw) ?? .leftNotch

        let tmRaw = ud.string(forKey: Keys.themeMode) ?? ThemeMode.dark.rawValue
        self.themeMode = ThemeMode(rawValue: tmRaw) ?? .dark

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 6
        self.urlSession = URLSession(configuration: config)

        lightHaptic.prepare()
        mediumHaptic.prepare()
        applyOrientationLock()
        applyWakeLock()

        if !host.isEmpty && !authToken.isEmpty {
            connectWebSocket()
        } else {
            showConnectSheet = true
        }
    }

    public func applyWakeLock() {
        UIApplication.shared.isIdleTimerDisabled = wakeLockEnabled
    }

    public func applyOrientationLock() {
        let mask = landscapeMode.interfaceMask
        OrientationAppDelegate.orientationMask = mask
        if #available(iOS 16.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
                    for window in windowScene.windows {
                        window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                    }
                }
            }
        } else {
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    public func playFeedback(heavy: Bool = false) {
        if hapticEnabled {
            if heavy {
                mediumHaptic.impactOccurred()
            } else {
                lightHaptic.impactOccurred()
            }
        }
        if soundEnabled {
            AudioServicesPlaySystemSound(1104)
        }
    }

    public func showToast(_ text: String) {
        toastWorkItem?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = text
        }
        let item = DispatchWorkItem { [weak self] in
            withAnimation(.easeIn(duration: 0.2)) {
                self?.toastMessage = nil
            }
        }
        toastWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: item)
    }

    // MARK: - Auth & WebSocket Lifecycle

    public func authenticateAndConnect(host: String, port: Int, pin: String) async -> String? {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPin = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty, port >= 1024, port <= 65535 else {
            return "Địa chỉ IP hoặc cổng không hợp lệ."
        }
        guard cleanPin.count == 6, cleanPin.allSatisfy({ $0.isNumber }) else {
            return "Vui lòng nhập đủ 6 chữ số PIN."
        }
        guard let url = URL(string: "http://\(cleanHost):\(port)/api/auth") else {
            return "URL máy chủ không hợp lệ."
        }

        status = .connecting("Đang xác thực...")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 5
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["pin": cleanPin, "device": deviceId]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await urlSession.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                status = .offline("Lỗi kết nối")
                return "Không nhận được phản hồi từ PC."
            }
            if http.statusCode == 401 {
                status = .offline("Sai mã PIN")
                return "Mã PIN không đúng."
            }
            guard http.statusCode == 200,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = obj["ok"] as? Bool, ok,
                  let token = obj["token"] as? String, !token.isEmpty else {
                status = .offline("Lỗi xác thực")
                return "Máy tính từ chối kết nối (HTTP \(http.statusCode))."
            }

            self.host = cleanHost
            self.port = port
            self.authToken = token
            let ud = UserDefaults.standard
            ud.set(cleanHost, forKey: Keys.host)
            ud.set(port, forKey: Keys.port)
            ud.set(token, forKey: Keys.token)

            disconnectSocket(keepReconnectStopped: true)
            connectWebSocket()
            return nil
        } catch {
            status = .offline("Không tìm thấy PC")
            return "Không kết nối được tới \(cleanHost):\(port). Hãy kiểm tra Wi-Fi và Firewall LAN."
        }
    }

    public func connectFromQR(_ raw: String) async -> Bool {
        guard let parsed = WinTouchProtocol.parseConnectionURL(raw) else {
            showToast("Mã QR không đúng định dạng WinTouch")
            return false
        }
        if let err = await authenticateAndConnect(host: parsed.host, port: parsed.port, pin: parsed.pin) {
            showToast(err)
            return false
        }
        showConnectSheet = false
        showToast("Đã kết nối tới \(parsed.host)")
        return true
    }

    public func forgetConnectionAndPrompt() {
        authToken = ""
        UserDefaults.standard.removeObject(forKey: Keys.token)
        disconnectSocket(keepReconnectStopped: true)
        status = .offline("Chưa kết nối")
        showConnectSheet = true
    }

    public func handleForegroundReturn() {
        applyWakeLock()
        applyOrientationLock()
        if !host.isEmpty && !authToken.isEmpty && webSocketTask == nil {
            connectWebSocket()
        }
    }

    public func connectWebSocket() {
        guard !host.isEmpty && !authToken.isEmpty else {
            status = .offline("Chưa kết nối")
            showConnectSheet = true
            return
        }
        if webSocketTask != nil { return }

        reconnectWorkItem?.cancel()
        status = .connecting("Đang kết nối...")
        isSocketOpened = false

        var comps = URLComponents()
        comps.scheme = "ws"
        comps.host = host
        comps.port = port
        comps.path = "/ws"
        comps.queryItems = [
            URLQueryItem(name: "token", value: authToken),
            URLQueryItem(name: "device", value: deviceId)
        ]

        guard let url = comps.url else {
            status = .offline("URL lỗi")
            return
        }

        let task = urlSession.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()
        receiveNextMessage(for: task)
        sendPing(for: task)

        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let activeTask = self.webSocketTask else { return }
                self.sendPing(for: activeTask)
            }
        }
    }

    public func disconnectSocket(keepReconnectStopped: Bool) {
        reconnectWorkItem?.cancel()
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        if keepReconnectStopped {
            reconnectDelay = 0.8
        }
    }

    private func sendPing(for task: URLSessionWebSocketTask) {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        sendDict(["t": "ping", "ts": ts], over: task)
    }

    private func receiveNextMessage(for task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                guard self.webSocketTask === task else { return }

                switch result {
                case .success(let message):
                    if !self.isSocketOpened {
                        self.isSocketOpened = true
                        self.reconnectDelay = 0.8
                        self.status = .online(nil)
                        self.showConnectSheet = false
                    }
                    if case .string(let text) = message {
                        self.handleIncomingJSON(text)
                    }
                    self.receiveNextMessage(for: task)

                case .failure:
                    await self.handleSocketDrop(task: task)
                }
            }
        }
    }

    private func handleIncomingJSON(_ text: String) {
        guard let data = text.data(using: .utf8),
              let msg = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = msg["t"] as? String else { return }

        switch type {
        case "pong":
            if let ts = msg["ts"] as? Double {
                let now = Date().timeIntervalSince1970 * 1000
                let rtt = max(1, Int(round(now - ts)))
                status = .online(rtt)
            } else {
                status = .online(nil)
            }
        case "clip":
            clipboardText = msg["s"] as? String ?? ""
            showToast("Đã lấy Clipboard từ PC")
        case "clip_ok":
            let pasted = msg["pasted"] as? Bool ?? false
            showToast(pasted ? "Đã dán lên PC" : "Đã gửi vào Clipboard PC")
        case "pwr_ok":
            let ok = msg["ok"] as? Bool ?? false
            showToast(ok ? "Đã gửi lệnh nguồn PC" : "Không thể thực hiện lệnh nguồn")
        default:
            break
        }
    }

    private func handleSocketDrop(task: URLSessionWebSocketTask) async {
        guard webSocketTask === task else { return }
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask = nil

        if !isSocketOpened && !authToken.isEmpty {
            // Check if token expired due to PIN change on PC
            if let url = URL(string: "http://\(host):\(port)/api/auth") {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.timeoutInterval = 3
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try? JSONSerialization.data(withJSONObject: ["token": authToken, "device": deviceId])
                if let (_, resp) = try? await urlSession.data(for: req),
                   let http = resp as? HTTPURLResponse, http.statusCode == 401 {
                    authToken = ""
                    UserDefaults.standard.removeObject(forKey: Keys.token)
                    status = .offline("PIN đã đổi")
                    showConnectSheet = true
                    return
                }
            }
        }

        status = .offline("Mất kết nối")
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 1.5, 5.0)
        let work = DispatchWorkItem { [weak self] in
            self?.connectWebSocket()
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: - Outbound Commands

    private func sendDict(_ dict: [String: Any], over explicitTask: URLSessionWebSocketTask? = nil) {
        guard let task = explicitTask ?? webSocketTask,
              let json = WinTouchProtocol.encodeJSON(dict) else { return }
        task.send(.string(json)) { _ in }
    }

    public func sendMouseMove(dx: Double, dy: Double) {
        sendDict(["t": "m", "dx": (dx * 100).rounded() / 100, "dy": (dy * 100).rounded() / 100])
    }

    public func sendMouseButton(_ button: String, action: String) {
        sendDict(["t": "mb", "b": button, "a": action])
    }

    public func sendScroll(dx: Double, dy: Double) {
        sendDict(["t": "sc", "dx": Int(round(dx)), "dy": Int(round(dy))])
    }

    public func sendZoom(delta: Int) {
        sendDict(["t": "zm", "d": delta])
    }

    public func sendText(_ text: String) {
        guard !text.isEmpty else { return }
        sendDict(["t": "txt", "s": text])
    }

    public func toggleDragLock(_ force: Bool? = nil) {
        let next = force ?? !dragLocked
        dragLocked = next
        sendMouseButton("left", action: next ? "down" : "up")
        playFeedback(heavy: next)
    }

    public func toggleModifier(_ mod: String) {
        let now = Date()
        let prevTap = lastModTap[mod] ?? .distantPast
        lastModTap[mod] = now

        if let cur = stickyMods[mod] {
            if cur == .once && now.timeIntervalSince(prevTap) < 0.35 {
                stickyMods[mod] = .locked
            } else {
                stickyMods.removeValue(forKey: mod)
            }
        } else {
            stickyMods[mod] = .once
        }
        playFeedback()
    }

    public func sendKey(_ keyName: String) {
        let activeMods = Array(stickyMods.keys)
        if !activeMods.isEmpty {
            sendDict(["t": "combo", "mods": activeMods, "k": keyName])
            for (k, v) in stickyMods where v == .once {
                stickyMods.removeValue(forKey: k)
            }
        } else {
            sendDict(["t": "k", "k": keyName, "a": "press"])
        }
        playFeedback()
    }

    public func sendClipboard(text: String, paste: Bool) {
        sendDict(["t": "clip_set", "s": text, "paste": paste])
        playFeedback()
    }

    public func requestClipboard() {
        sendDict(["t": "clip_get"])
    }

    public func sendPower(_ action: String) {
        sendDict(["t": "pwr", "a": action])
        playFeedback(heavy: true)
    }
}
