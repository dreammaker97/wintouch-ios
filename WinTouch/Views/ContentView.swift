import SwiftUI

struct ContentView: View {
    @ObservedObject var store: WinTouchStore
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        ZStack {
            appBackground
                .ignoresSafeArea()

            VStack(spacing: 8) {
                topBar

                if store.activeTab == .trackpad {
                    TrackpadView(store: store)
                } else {
                    PCKeyboardView(store: store)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            if store.showIosKeyboard {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        store.showIosKeyboard = false
                    }
                NativeKeyboardOverlay(store: store)
            }

            if let toast = store.toastMessage {
                VStack {
                    HStack(spacing: 10) {
                        Text(toast)
                            .font(.system(size: 13, weight: .semibold))
                        Button {
                            store.toastMessage = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .padding(5)
                                .background(Color.primary.opacity(0.14))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.primary.opacity(0.18), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
                    .padding(.top, 52)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .preferredColorScheme(preferredScheme)
        .sheet(isPresented: $store.showConnectSheet) {
            ConnectSheet(store: store)
        }
        .sheet(isPresented: $store.showClipboardSheet) {
            ClipboardSheet(store: store)
        }
        .sheet(isPresented: $store.showPowerSheet) {
            PowerSheet(store: store)
        }
        .sheet(isPresented: $store.showSettingsSheet) {
            SettingsSheet(store: store)
        }
    }

    private var preferredScheme: ColorScheme? {
        switch store.themeMode {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    private var effectiveIsLight: Bool {
        (preferredScheme ?? systemScheme) == .light
    }

    private var appBackground: some View {
        ZStack {
            LinearGradient(
                colors: effectiveIsLight ? [
                    Color(red: 0.93, green: 0.95, blue: 0.98),
                    Color(red: 0.87, green: 0.91, blue: 0.96)
                ] : [
                    Color(red: 0.024, green: 0.035, blue: 0.075),
                    Color(red: 0.047, green: 0.075, blue: 0.149)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color(red: 0.22, green: 0.74, blue: 0.97).opacity(0.16), .clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 340
            )
            RadialGradient(
                colors: [Color(red: 0.51, green: 0.55, blue: 0.97).opacity(0.16), .clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 340
            )
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                store.showConnectSheet = true
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(store.status.color)
                        .frame(width: 9, height: 9)
                        .shadow(color: store.status.color.opacity(0.7), radius: 5)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("WinTouch")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                        Text(store.status.label)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 2) {
                modeSegment("Trackpad", tab: .trackpad)
                modeSegment("Bàn phím PC", tab: .keyboard)
            }
            .padding(3)
            .background(Color.primary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            Spacer()

            HStack(spacing: 6) {
                topIconButton(systemName: "doc.on.clipboard") {
                    store.showClipboardSheet = true
                }
                topIconButton(systemName: "power") {
                    store.showPowerSheet = true
                }
                topIconButton(systemName: "gearshape") {
                    store.showSettingsSheet = true
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.16), lineWidth: 1)
        )
    }

    private func modeSegment(_ title: String, tab: MainControlTab) -> some View {
        let active = store.activeTab == tab
        return Button {
            store.activeTab = tab
            if tab == .keyboard {
                store.showIosKeyboard = false
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .foregroundColor(active ? Color(red: 0.02, green: 0.07, blue: 0.12) : .secondary)
                .background(active ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func topIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
