import SwiftUI
import UIKit

struct ConnectSheet: View {
    @ObservedObject var store: WinTouchStore
    @Environment(\.dismiss) private var dismiss

    @State private var hostInput: String = ""
    @State private var portInput: String = "8765"
    @State private var pinInput: String = ""
    @State private var errorMsg: String?
    @State private var isConnecting = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Button {
                        store.showQRScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Quét mã QR trên màn hình PC")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                }

                Section(header: Text("Hoặc nhập thủ công")) {
                    TextField("IP máy tính (VD: 192.168.1.100)", text: $hostInput)
                        .keyboardType(.decimalPad)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    TextField("Cổng (mặc định 8765)", text: $portInput)
                        .keyboardType(.numberPad)

                    TextField("Mã PIN 6 số", text: $pinInput)
                        .keyboardType(.numberPad)
                }

                if let err = errorMsg {
                    Section {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.system(size: 13))
                    }
                }

                Section {
                    Button {
                        submitManual()
                    } label: {
                        HStack {
                            Spacer()
                            if isConnecting {
                                ProgressView()
                            } else {
                                Text("Kết nối ngay")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            Spacer()
                        }
                    }
                    .disabled(isConnecting)
                }
            }
            .navigationTitle("Kết nối WinTouch PC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !store.authToken.isEmpty {
                        Button("Đóng") { dismiss() }
                    }
                }
            }
            .onAppear {
                hostInput = store.host
                portInput = String(store.port)
            }
            .sheet(isPresented: $store.showQRScanner) {
                QRScannerSheet { scanned in
                    Task {
                        if await store.connectFromQR(scanned) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func submitManual() {
        errorMsg = nil
        let port = Int(portInput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 8765
        isConnecting = true
        Task {
            let err = await store.authenticateAndConnect(host: hostInput, port: port, pin: pinInput)
            isConnecting = false
            if let err = err {
                errorMsg = err
            } else {
                dismiss()
            }
        }
    }
}

struct ClipboardSheet: View {
    @ObservedObject var store: WinTouchStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                TextEditor(text: $store.clipboardText)
                    .padding(8)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.16), lineWidth: 1)
                    )

                HStack(spacing: 8) {
                    Button("Gửi Clipboard PC") {
                        store.sendClipboard(text: store.clipboardText, paste: false)
                    }
                    .buttonStyle(ActionPillStyle(primary: false))

                    Button("Gửi & Dán (Ctrl+V)") {
                        store.sendClipboard(text: store.clipboardText, paste: true)
                        dismiss()
                    }
                    .buttonStyle(ActionPillStyle(primary: true))

                    Button("Lấy từ PC") {
                        store.requestClipboard()
                    }
                    .buttonStyle(ActionPillStyle(primary: false))

                    Button("Chép vào iPhone") {
                        UIPasteboard.general.string = store.clipboardText
                        store.showToast("Đã chép vào Clipboard iPhone")
                    }
                    .buttonStyle(ActionPillStyle(primary: false))
                }
            }
            .padding()
            .navigationTitle("Clipboard 2 Chiều")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct PowerSheet: View {
    @ObservedObject var store: WinTouchStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmAction: (code: String, label: String)?
    @State private var showConfirm = false

    private let actions: [(code: String, title: String, sub: String, desc: String, tint: Color)] = [
        ("lock", "Khóa máy", "Lock Windows (Win + L)", "Khóa màn hình (Win + L)", .accentColor),
        ("sleep", "Ngủ (Sleep)", "Tiết kiệm điện", "Đưa máy tính vào chế độ Ngủ (Sleep)", .accentColor),
        ("restart", "Khởi động lại", "Restart PC", "Khởi động lại máy tính ngay lập tức", .orange),
        ("shutdown", "Tắt máy", "Shutdown PC", "Tắt nguồn máy tính ngay lập tức", .red)
    ]

    var body: some View {
        NavigationView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(actions, id: \.code) { item in
                    Button {
                        confirmAction = (item.code, item.desc)
                        showConfirm = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            Text(item.sub)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(item.tint.opacity(0.45), lineWidth: 1.2)
                        )
                    }
                }
            }
            .padding()
            .navigationTitle("Điều khiển Nguồn PC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .alert("Xác nhận thao tác nguồn", isPresented: $showConfirm) {
                Button("Hủy", role: .cancel) {
                    confirmAction = nil
                }
                Button("Thực hiện", role: .destructive) {
                    if let action = confirmAction {
                        store.sendPower(action.code)
                        confirmAction = nil
                        dismiss()
                    }
                }
            } message: {
                Text("Bạn có chắc muốn thực hiện: \(confirmAction?.label ?? "")?")
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct SettingsSheet: View {
    @ObservedObject var store: WinTouchStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Trackpad & Phản hồi")) {
                    VStack(alignment: .leading) {
                        Text("Độ nhạy chuột: \(String(format: "%.1fx", store.sensitivity))")
                        Slider(value: $store.sensitivity, in: 0.5...4.0, step: 0.1)
                    }
                    Toggle("Gia tốc chuột (kiểu MacBook)", isOn: $store.accelEnabled)
                    Toggle("Cuộn tự nhiên (Natural Scroll)", isOn: $store.naturalScroll)
                    Toggle("Rung phản hồi nhẹ (Haptic)", isOn: $store.hapticEnabled)
                    Toggle("Âm thanh gõ phím nhẹ", isOn: $store.soundEnabled)
                    Toggle("Giữ sáng màn hình khi đang dùng", isOn: $store.wakeLockEnabled)
                }

                Section(header: Text("Xoay ngang & Giao diện")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Chiều xoay ngang")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Picker("Chiều xoay ngang", selection: $store.landscapeMode) {
                            ForEach(LandscapeLockMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Giao diện")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Picker("Giao diện", selection: $store.themeMode) {
                            ForEach(ThemeMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section(header: Text("Kết nối PC")) {
                    if !store.host.isEmpty {
                        Text("Đang lưu: \(store.host):\(store.port)")
                            .foregroundColor(.secondary)
                    }
                    Button("Quét QR / Đổi máy tính & PIN") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            store.forgetConnectionAndPrompt()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Cài đặt WinTouch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct ActionPillStyle: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(primary ? Color(red: 0.02, green: 0.07, blue: 0.12) : .primary)
            .background(primary ? Color.accentColor : Color.primary.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}
