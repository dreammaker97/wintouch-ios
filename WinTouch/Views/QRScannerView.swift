import AVFoundation
import SwiftUI
import UIKit

struct QRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onScanned: (String) -> Void
    @State private var cameraError: String?

    var body: some View {
        NavigationView {
            ZStack {
                if let err = cameraError {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text(err)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                } else {
                    QRScannerRepresentable(
                        onCode: { code in
                            onScanned(code)
                            dismiss()
                        },
                        onError: { err in
                            cameraError = err
                        }
                    )
                    .ignoresSafeArea()

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .frame(width: 210, height: 210)
                        .shadow(color: Color.accentColor.opacity(0.6), radius: 12)
                }
            }
            .navigationTitle("Quét QR trên WinTouch PC")
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

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    var onError: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onCode = onCode
        vc.onError = onError
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didEmit = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupCamera()
                    } else {
                        self.onError?("Bạn chưa cấp quyền Camera. Hãy vào Cài đặt iPhone để bật Camera cho WinTouch.")
                    }
                }
            }
        default:
            onError?("Camera bị từ chối quyền truy cập. Hãy mở quyền trong Cài đặt iPhone.")
        }
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            onError?("Không tìm thấy Camera khả dụng trên thiết bị.")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onError?("Không thể khởi tạo bộ đọc mã QR.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        self.previewLayer = preview
        updatePreviewOrientation()

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updatePreviewOrientation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
            }
        }
    }

    private func updatePreviewOrientation() {
        guard let conn = previewLayer?.connection, conn.isVideoOrientationSupported else { return }
        let iface = view.window?.windowScene?.interfaceOrientation ?? .landscapeRight
        switch iface {
        case .landscapeLeft: conn.videoOrientation = .landscapeLeft
        case .landscapeRight: conn.videoOrientation = .landscapeRight
        case .portraitUpsideDown: conn.videoOrientation = .portraitUpsideDown
        default: conn.videoOrientation = .landscapeRight
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didEmit,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let raw = obj.stringValue else { return }
        didEmit = true
        session.stopRunning()
        onCode?(raw)
    }
}
