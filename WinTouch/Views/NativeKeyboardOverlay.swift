import SwiftUI
import UIKit

final class SentinelTextField: UITextField {
    var onEmptyBackspace: (() -> Void)?

    override func deleteBackward() {
        if (text ?? "").count <= 1 {
            onEmptyBackspace?()
            return
        }
        super.deleteBackward()
    }
}

struct LiveImeFieldRepresentable: UIViewRepresentable {
    @ObservedObject var store: WinTouchStore
    var shouldFocus: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> SentinelTextField {
        let tf = SentinelTextField()
        tf.text = " "
        tf.tintColor = .clear
        tf.textColor = .clear
        tf.backgroundColor = .clear
        tf.autocorrectionType = .yes
        tf.autocapitalizationType = .sentences
        tf.spellCheckingType = .yes
        tf.returnKeyType = .send
        tf.delegate = context.coordinator
        tf.onEmptyBackspace = { [weak store] in
            store?.sendKey("Backspace")
        }
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return tf
    }

    func updateUIView(_ uiView: SentinelTextField, context: Context) {
        context.coordinator.store = store
        if shouldFocus && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var store: WinTouchStore
        private var prevValue: String = " "

        init(store: WinTouchStore) {
            self.store = store
        }

        private func resetSentinel(_ tf: UITextField) {
            prevValue = " "
            tf.text = " "
        }

        @objc func textChanged(_ tf: UITextField) {
            if tf.markedTextRange != nil { return }
            let cur = tf.text ?? ""
            if cur.isEmpty {
                store.sendKey("Backspace")
                resetSentinel(tf)
                return
            }
            let normalized = cur.hasPrefix(" ") ? cur : (" " + cur)
            let diff = WinTouchProtocol.computeImeDiff(prev: prevValue, next: normalized)
            for _ in 0..<diff.backspaces {
                store.sendKey("Backspace")
            }
            if !diff.insertText.isEmpty {
                if !store.stickyMods.isEmpty && diff.insertText.count == 1 {
                    store.sendKey(diff.insertText)
                    resetSentinel(tf)
                    return
                }
                store.sendText(diff.insertText)
            }
            prevValue = normalized
            if normalized.count > 80 && normalized.hasSuffix(" ") {
                resetSentinel(tf)
            }
            store.playFeedback()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            store.sendKey("Enter")
            resetSentinel(textField)
            return false
        }
    }
}

struct NativeKeyboardOverlay: View {
    @ObservedObject var store: WinTouchStore
    @State private var composeText: String = ""
    @State private var showFnRow: Bool = false
    @FocusState private var composeFocused: Bool

    private let quickKeys: [(String, String)] = [
        ("Esc", "Esc"), ("Tab", "Tab"), ("Del", "Delete"),
        ("⌫", "Backspace"), ("↵", "Enter"),
        ("←", "ArrowLeft"), ("↑", "ArrowUp"), ("↓", "ArrowDown"), ("→", "ArrowRight"),
        ("Home", "Home"), ("End", "End"), ("PgUp", "PageUp"), ("PgDn", "PageDown")
    ]

    var body: some View {
        VStack(spacing: 6) {
            Spacer()
            panelContent
        }
        .onAppear {
            if store.composeMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    composeFocused = true
                }
            }
        }
    }

    private var panelContent: some View {
        VStack(spacing: 6) {
            headerRow
            specialStrip
            if showFnRow {
                fnStrip
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.16), lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            if store.composeMode {
                composeInputGroup
            } else {
                liveInputGroup
            }

            Button("Xong") {
                composeFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                store.showIosKeyboard = false
            }
            .font(.system(size: 13, weight: .bold))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.primary.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    @ViewBuilder
    private var composeInputGroup: some View {
        TextField("Nhập / đọc tiếng Việt rồi bấm Gửi...", text: $composeText)
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color.primary.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .focused($composeFocused)
            .onSubmit { sendComposeText() }

        Button("Gửi") { sendComposeText() }
            .font(.system(size: 13, weight: .bold))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.accentColor)
            .foregroundColor(Color(red: 0.02, green: 0.07, blue: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

        Button("Dán") {
            guard !composeText.isEmpty else { return }
            store.sendClipboard(text: composeText, paste: true)
            composeText = ""
        }
        .font(.system(size: 13, weight: .bold))
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.primary.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var liveInputGroup: some View {
        ZStack(alignment: .leading) {
            LiveImeFieldRepresentable(store: store, shouldFocus: !store.composeMode)
                .frame(height: 36)
            HStack {
                Image(systemName: "character.cursor.ibeam")
                    .foregroundColor(.accentColor)
                Text("Đang gõ tiếng Việt trực tiếp sang PC...")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 10)
            .allowsHitTesting(false)
        }
        .frame(height: 36)
        .background(Color.primary.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var specialStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(["Ctrl", "Alt", "Shift", "Win"], id: \.self) { mod in
                    ModifierChipButton(title: mod, state: store.stickyMods[mod]) {
                        store.toggleModifier(mod)
                    }
                }

                ForEach(quickKeys, id: \.1) { item in
                    Button {
                        store.sendKey(item.1)
                    } label: {
                        Text(item.0)
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 10)
                            .frame(minWidth: 38, height: 32)
                            .background(Color.primary.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(Color.primary.opacity(0.16), lineWidth: 1)
                            )
                    }
                }

                Button {
                    showFnRow.toggle()
                } label: {
                    Text("F1-F12")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(showFnRow ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
        }
    }

    private var fnStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(1...12, id: \.self) { idx in
                    Button {
                        store.sendKey("F\(idx)")
                    } label: {
                        Text("F\(idx)")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 42, height: 32)
                            .background(Color.primary.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
            }
        }
    }

    private func sendComposeText() {
        guard !composeText.isEmpty else { return }
        store.sendText(composeText)
        composeText = ""
        store.playFeedback()
    }
}
