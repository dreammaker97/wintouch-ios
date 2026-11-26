import SwiftUI
import UIKit

struct TrackpadSurfaceRepresentable: UIViewRepresentable {
    @ObservedObject var store: WinTouchStore
    var onFirstTouch: () -> Void

    func makeUIView(context: Context) -> TrackpadUIView {
        let view = TrackpadUIView()
        view.store = store
        view.onFirstTouch = onFirstTouch
        return view
    }

    func updateUIView(_ uiView: TrackpadUIView, context: Context) {
        uiView.store = store
    }
}

final class TrackpadUIView: UIView {
    weak var store: WinTouchStore?
    var onFirstTouch: (() -> Void)?

    private var activeTouches: [UITouch: CGPoint] = [:]
    private var maxTouchCount = 0
    private var gestureStartTime: CFTimeInterval = 0
    private var lastTouchTime: CFTimeInterval = 0
    private var totalMoveDist: CGFloat = 0
    private var lastTapUpTime: CFTimeInterval = 0
    private var tapDragActive = false
    private var prevTwoFinger: (cx: CGFloat, cy: CGFloat, dist: CGFloat)?

    private var pendingMoveX: Double = 0
    private var pendingMoveY: Double = 0
    private var pendingScrollX: Double = 0
    private var pendingScrollY: Double = 0
    private var pendingZoom: Double = 0
    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        let link = CADisplayLink(target: self, selector: #selector(flushPending))
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    @objc private func flushPending() {
        guard let store = store else { return }
        if abs(pendingMoveX) > 0.01 || abs(pendingMoveY) > 0.01 {
            store.sendMouseMove(dx: pendingMoveX, dy: pendingMoveY)
            pendingMoveX = 0
            pendingMoveY = 0
        }
        if abs(pendingScrollX) > 0.5 || abs(pendingScrollY) > 0.5 {
            store.sendScroll(dx: pendingScrollX, dy: pendingScrollY)
            pendingScrollX = 0
            pendingScrollY = 0
        }
        if abs(pendingZoom) >= 24 {
            store.sendZoom(delta: Int(round(pendingZoom)))
            pendingZoom = 0
        }
    }

    private func spawnRipple(at point: CGPoint) {
        let ripple = UIView(frame: CGRect(x: point.x - 22, y: point.y - 22, width: 44, height: 44))
        ripple.isUserInteractionEnabled = false
        ripple.layer.cornerRadius = 22
        ripple.layer.borderWidth = 1.5
        ripple.layer.borderColor = UIColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 0.75).cgColor
        ripple.backgroundColor = UIColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 0.22)
        ripple.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        addSubview(ripple)

        UIView.animate(withDuration: 0.42, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            ripple.transform = CGAffineTransform(scaleX: 1.75, y: 1.75)
            ripple.alpha = 0
        } completion: { _ in
            ripple.removeFromSuperview()
        }
    }

    private func currentCentroidAndDist() -> (cx: CGFloat, cy: CGFloat, dist: CGFloat)? {
        let pts = Array(activeTouches.values)
        guard pts.count >= 2 else { return nil }
        let cx = (pts[0].x + pts[1].x) * 0.5
        let cy = (pts[0].y + pts[1].y) * 0.5
        let dist = hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y)
        return (cx, cy, dist)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onFirstTouch?()
        let now = CACurrentMediaTime()
        if activeTouches.isEmpty {
            maxTouchCount = 0
            gestureStartTime = now
            totalMoveDist = 0
            lastTouchTime = now
            if touches.count == 1 && (now - lastTapUpTime) < 0.27 {
                tapDragActive = true
                store?.sendMouseButton("left", action: "down")
                store?.dragLocked = true
            }
        }

        for t in touches {
            let loc = t.location(in: self)
            activeTouches[t] = loc
            spawnRipple(at: loc)
        }
        maxTouchCount = max(maxTouchCount, activeTouches.count)

        if activeTouches.count >= 2 {
            if tapDragActive {
                tapDragActive = false
                store?.sendMouseButton("left", action: "up")
                store?.dragLocked = false
            }
            prevTwoFinger = currentCentroidAndDist()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !activeTouches.isEmpty, let store = store else { return }
        let now = CACurrentMediaTime()
        let dtMs = max(4.0, (now - lastTouchTime) * 1000.0)
        lastTouchTime = now

        if activeTouches.count == 1, let t = touches.first, let prev = activeTouches[t] {
            let loc = t.location(in: self)
            let dx = Double(loc.x - prev.x)
            let dy = Double(loc.y - prev.y)
            activeTouches[t] = loc

            let dist = hypot(dx, dy)
            totalMoveDist += CGFloat(dist)

            var gain = store.sensitivity
            if store.accelEnabled {
                let speed = dist / dtMs
                gain *= (1.0 + min(speed * 1.1, 2.4))
            }
            pendingMoveX += dx * gain
            pendingMoveY += dy * gain
        } else if activeTouches.count >= 2 {
            for t in touches {
                if activeTouches[t] != nil {
                    activeTouches[t] = t.location(in: self)
                }
            }
            if let cur = currentCentroidAndDist(), let prev = prevTwoFinger {
                let dcx = Double(cur.cx - prev.cx)
                let dcy = Double(cur.cy - prev.cy)
                let dDist = Double(cur.dist - prev.dist)
                totalMoveDist += CGFloat(hypot(dcx, dcy) + abs(dDist))

                if abs(dDist) > 3.5 && abs(dDist) > hypot(dcx, dcy) * 0.9 {
                    pendingZoom += dDist * 3.2
                } else {
                    let dir = store.naturalScroll ? 1.0 : -1.0
                    pendingScrollY += dcy * 4.5 * dir
                    pendingScrollX -= dcx * 4.5 * dir
                }
                prevTwoFinger = cur
            }
        }
    }

    private func handleEnded(_ touches: Set<UITouch>) {
        guard !activeTouches.isEmpty else { return }
        for t in touches {
            activeTouches.removeValue(forKey: t)
        }
        if activeTouches.count < 2 {
            prevTwoFinger = nil
        }
        if activeTouches.isEmpty {
            let dur = CACurrentMediaTime() - gestureStartTime
            if tapDragActive {
                tapDragActive = false
                store?.sendMouseButton("left", action: "up")
                store?.dragLocked = false
            } else if dur < 0.26 && totalMoveDist < 14 {
                if maxTouchCount == 1 {
                    store?.sendMouseButton("left", action: "click")
                    store?.playFeedback()
                    lastTapUpTime = CACurrentMediaTime()
                } else if maxTouchCount == 2 {
                    store?.sendMouseButton("right", action: "click")
                    store?.playFeedback(heavy: true)
                }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleEnded(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleEnded(touches)
    }
}

struct TrackpadView: View {
    @ObservedObject var store: WinTouchStore
    @State private var hintsFaded = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                DotGridBackdrop()
                    .allowsHitTesting(false)

                VStack(spacing: 6) {
                    Text("Trackpad Đa Điểm")
                        .font(.system(size: 16, weight: .bold))
                        .opacity(0.75)
                    VStack(spacing: 3) {
                        Text("1 ngón: Di chuột / Chạm Click")
                        Text("Chạm đúp giữ: Kéo thả · 2 ngón chạm: Chuột phải")
                        Text("2 ngón vuốt: Cuộn trang · 2 ngón chụm: Phóng to / Thu nhỏ")
                    }
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .opacity(hintsFaded ? 0.22 : 0.9)
                .animation(.easeOut(duration: 0.35), value: hintsFaded)
                .allowsHitTesting(false)

                TrackpadSurfaceRepresentable(store: store) {
                    if !hintsFaded { hintsFaded = true }
                }

                if store.dragLocked {
                    VStack {
                        Text("ĐANG GIỮ CHUỘT TRÁI")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.02, green: 0.07, blue: 0.12))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                            .padding(.top, 10)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Button {
                            store.showIosKeyboard = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "keyboard")
                                Text("Bàn phím iPhone")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.22, green: 0.74, blue: 0.97),
                                        Color(red: 0.51, green: 0.55, blue: 0.97)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
                        }

                        Button {
                            store.composeMode.toggle()
                            store.showToast(store.composeMode ? "Chế độ: Nhập đoạn rồi gửi" : "Chế độ: Gõ trực tiếp")
                        } label: {
                            Text(store.composeMode ? "Nhập đoạn" : "Gõ trực tiếp")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.primary.opacity(0.16), lineWidth: 1))
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )

            // Bottom Tactile Mouse Buttons Row
            HStack(spacing: 8) {
                HoldMouseButton(title: "Trái", weight: 1.25) { isDown in
                    if isDown && store.dragLocked {
                        store.toggleDragLock(false)
                    }
                    store.sendMouseButton("left", action: isDown ? "down" : "up")
                    if isDown { store.playFeedback() }
                }

                HoldMouseButton(title: "Giữa", weight: 0.75) { isDown in
                    store.sendMouseButton("middle", action: isDown ? "down" : "up")
                    if isDown { store.playFeedback() }
                }

                Button {
                    store.toggleDragLock()
                } label: {
                    Text("Kéo thả")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundColor(store.dragLocked ? Color(red: 0.02, green: 0.07, blue: 0.12) : .primary)
                        .background(store.dragLocked ? Color.accentColor : Color.clear)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.primary.opacity(store.dragLocked ? 0 : 0.15), lineWidth: 1)
                        )
                }
                .frame(maxWidth: .infinity)

                HoldMouseButton(title: "Phải", weight: 1.25) { isDown in
                    store.sendMouseButton("right", action: isDown ? "down" : "up")
                    if isDown { store.playFeedback() }
                }
            }
            .frame(height: 44)
        }
    }
}

private struct HoldMouseButton: View {
    let title: String
    let weight: CGFloat
    let onStateChange: (Bool) -> Void
    @State private var isPressed = false

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isPressed ? Color.accentColor.opacity(0.22) : Color.clear)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isPressed ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onStateChange(true)
                        }
                    }
                    .onEnded { _ in
                        if isPressed {
                            isPressed = false
                            onStateChange(false)
                        }
                    }
            )
    }
}

private struct DotGridBackdrop: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 22
            let dotColor = Color.secondary.opacity(0.22)
            var y: CGFloat = 14
            while y < size.height {
                var x: CGFloat = 14
                while x < size.width {
                    let rect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    x += step
                }
                y += step
            }
        }
    }
}
