import SwiftUI

struct PCKeyDef: Identifiable {
    let id = UUID()
    let label: String
    let keyCode: String?
    let modName: String?
    let flex: CGFloat
    let isFn: Bool

    init(_ label: String, key: String? = nil, mod: String? = nil, flex: CGFloat = 1.0, fn: Bool = false) {
        self.label = label
        self.keyCode = key
        self.modName = mod
        self.flex = flex
        self.isFn = fn
    }
}

private let mainKeyRows: [[PCKeyDef]] = [
    [
        PCKeyDef("Esc", key: "Esc", fn: true), PCKeyDef("F1", key: "F1", fn: true), PCKeyDef("F2", key: "F2", fn: true),
        PCKeyDef("F3", key: "F3", fn: true), PCKeyDef("F4", key: "F4", fn: true), PCKeyDef("F5", key: "F5", fn: true),
        PCKeyDef("F6", key: "F6", fn: true), PCKeyDef("F7", key: "F7", fn: true), PCKeyDef("F8", key: "F8", fn: true),
        PCKeyDef("F9", key: "F9", fn: true), PCKeyDef("F10", key: "F10", fn: true), PCKeyDef("F11", key: "F11", fn: true),
        PCKeyDef("F12", key: "F12", fn: true), PCKeyDef("Prt", key: "PrintScreen", fn: true), PCKeyDef("Del", key: "Delete", fn: true)
    ],
    [
        PCKeyDef("`", key: "Backquote"), PCKeyDef("1", key: "1"), PCKeyDef("2", key: "2"), PCKeyDef("3", key: "3"),
        PCKeyDef("4", key: "4"), PCKeyDef("5", key: "5"), PCKeyDef("6", key: "6"), PCKeyDef("7", key: "7"),
        PCKeyDef("8", key: "8"), PCKeyDef("9", key: "9"), PCKeyDef("0", key: "0"), PCKeyDef("-", key: "Minus"),
        PCKeyDef("=", key: "Equal"), PCKeyDef("⌫", key: "Backspace", flex: 2.0)
    ],
    [
        PCKeyDef("Tab", key: "Tab", flex: 1.5), PCKeyDef("Q", key: "Q"), PCKeyDef("W", key: "W"), PCKeyDef("E", key: "E"),
        PCKeyDef("R", key: "R"), PCKeyDef("T", key: "T"), PCKeyDef("Y", key: "Y"), PCKeyDef("U", key: "U"),
        PCKeyDef("I", key: "I"), PCKeyDef("O", key: "O"), PCKeyDef("P", key: "P"), PCKeyDef("[", key: "BracketLeft"),
        PCKeyDef("]", key: "BracketRight"), PCKeyDef("\\", key: "Backslash", flex: 1.5)
    ],
    [
        PCKeyDef("Caps", key: "CapsLock", flex: 1.5), PCKeyDef("A", key: "A"), PCKeyDef("S", key: "S"), PCKeyDef("D", key: "D"),
        PCKeyDef("F", key: "F"), PCKeyDef("G", key: "G"), PCKeyDef("H", key: "H"), PCKeyDef("J", key: "J"),
        PCKeyDef("K", key: "K"), PCKeyDef("L", key: "L"), PCKeyDef(";", key: "Semicolon"), PCKeyDef("'", key: "Quote"),
        PCKeyDef("Enter", key: "Enter", flex: 2.5)
    ],
    [
        PCKeyDef("Shift", mod: "Shift", flex: 2.0), PCKeyDef("Z", key: "Z"), PCKeyDef("X", key: "X"), PCKeyDef("C", key: "C"),
        PCKeyDef("V", key: "V"), PCKeyDef("B", key: "B"), PCKeyDef("N", key: "N"), PCKeyDef("M", key: "M"),
        PCKeyDef(",", key: "Comma"), PCKeyDef(".", key: "Period"), PCKeyDef("/", key: "Slash"),
        PCKeyDef("↑", key: "ArrowUp"), PCKeyDef("Home", key: "Home", fn: true), PCKeyDef("End", key: "End", fn: true)
    ],
    [
        PCKeyDef("Ctrl", mod: "Ctrl", flex: 1.5), PCKeyDef("Win", mod: "Win"), PCKeyDef("Alt", mod: "Alt"),
        PCKeyDef("Space", key: "Space", flex: 4.5),
        PCKeyDef("PgUp", key: "PageUp", fn: true), PCKeyDef("PgDn", key: "PageDown", fn: true),
        PCKeyDef("←", key: "ArrowLeft"), PCKeyDef("↓", key: "ArrowDown"), PCKeyDef("→", key: "ArrowRight")
    ]
]

struct PCKeyboardView: View {
    @ObservedObject var store: WinTouchStore

    var body: some View {
        VStack(spacing: 7) {
            // Toolbar: Sticky modifiers + Numpad + Vietnamese iOS Keyboard trigger
            HStack(spacing: 6) {
                ForEach(["Ctrl", "Alt", "Shift", "Win"], id: \.self) { mod in
                    ModifierChipButton(title: mod, state: store.stickyMods[mod]) {
                        store.toggleModifier(mod)
                    }
                }

                Spacer()

                Button {
                    store.showNumpad.toggle()
                } label: {
                    Text("Numpad")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(store.showNumpad ? Color.accentColor.opacity(0.25) : Color.clear)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(store.showNumpad ? Color.accentColor : Color.primary.opacity(0.16), lineWidth: 1))
                }

                Button {
                    store.activeTab = .trackpad
                    store.showIosKeyboard = true
                } label: {
                    Text("Gõ Tiếng Việt")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.22, green: 0.74, blue: 0.97),
                                    Color(red: 0.51, green: 0.55, blue: 0.97)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            }

            // Full QWERTY + Optional Numpad
            HStack(spacing: 8) {
                GeometryReader { geo in
                    VStack(spacing: 4) {
                        ForEach(Array(mainKeyRows.enumerated()), id: \.offset) { _, row in
                            let totalUnits = row.reduce(CGFloat(0)) { $0 + $1.flex }
                            let totalGap = CGFloat(max(0, row.count - 1)) * 4
                            let availW = max(100, geo.size.width - totalGap)
                            HStack(spacing: 4) {
                                ForEach(row) { item in
                                    let w = availW * (item.flex / totalUnits)
                                    if let mod = item.modName {
                                        let mState = store.stickyMods[mod]
                                        KeyTileButton(
                                            label: item.label,
                                            isFn: false,
                                            modState: mState
                                        ) {
                                            store.toggleModifier(mod)
                                        }
                                        .frame(width: w)
                                    } else if let key = item.keyCode {
                                        KeyTileButton(
                                            label: item.label,
                                            isFn: item.isFn,
                                            modState: nil
                                        ) {
                                            store.sendKey(key)
                                        }
                                        .frame(width: w)
                                    }
                                }
                            }
                            .frame(maxHeight: .infinity)
                        }
                    }
                }

                if store.showNumpad {
                    NumpadGridView(store: store)
                        .frame(width: 170)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

private struct NumpadGridView: View {
    @ObservedObject var store: WinTouchStore

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                numKey("Num", "NumLock", fn: true)
                numKey("/", "NumpadDivide")
                numKey("*", "NumpadMultiply")
                numKey("-", "NumpadSubtract")
            }
            HStack(spacing: 4) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) { numKey("7", "Numpad7"); numKey("8", "Numpad8"); numKey("9", "Numpad9") }
                    HStack(spacing: 4) { numKey("4", "Numpad4"); numKey("5", "Numpad5"); numKey("6", "Numpad6") }
                }
                numKey("+", "NumpadAdd").frame(width: 39)
            }
            HStack(spacing: 4) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) { numKey("1", "Numpad1"); numKey("2", "Numpad2"); numKey("3", "Numpad3") }
                    HStack(spacing: 4) {
                        numKey("0", "Numpad0")
                        numKey(".", "NumpadDecimal").frame(width: 39)
                    }
                }
                numKey("↵", "NumpadEnter").frame(width: 39)
            }
        }
    }

    private func numKey(_ label: String, _ code: String, fn: Bool = false) -> some View {
        KeyTileButton(label: label, isFn: fn, modState: nil) {
            store.sendKey(code)
        }
    }
}

struct ModifierChipButton: View {
    let title: String
    let state: ModifierState?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundColor(fgColor)
                .background(bgColor)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(state == nil ? Color.primary.opacity(0.18) : Color.clear, lineWidth: 1)
                )
        }
    }

    private var fgColor: Color {
        switch state {
        case .once: return Color(red: 0.02, green: 0.07, blue: 0.12)
        case .locked: return .white
        case .none: return .primary
        }
    }

    private var bgColor: Color {
        switch state {
        case .once: return Color.accentColor
        case .locked: return Color(red: 0.51, green: 0.55, blue: 0.97)
        case .none: return Color.primary.opacity(0.08)
        }
    }
}

private struct KeyTileButton: View {
    let label: String
    let isFn: Bool
    let modState: ModifierState?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: isFn ? 10 : 11.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundColor(fgColor)
                .background(bgColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.16), lineWidth: 1)
                )
        }
        .buttonStyle(KeyPressButtonStyle())
    }

    private var fgColor: Color {
        if modState == .once { return Color(red: 0.02, green: 0.07, blue: 0.12) }
        if modState == .locked { return .white }
        return isFn ? .secondary : .primary
    }

    private var bgColor: Color {
        if modState == .once { return Color.accentColor }
        if modState == .locked { return Color(red: 0.51, green: 0.55, blue: 0.97) }
        return Color.primary.opacity(0.09)
    }
}

private struct KeyPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .brightness(configuration.isPressed ? 0.15 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
