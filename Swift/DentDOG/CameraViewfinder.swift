import SwiftUI
import AVFoundation

/// Owns the AVCaptureSession. Runs session start/stop on a background queue
/// per Apple's guidance (session.startRunning() blocks and must not run on
/// the main thread).
final class CameraSessionController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "dentdog.camera.session")
    private var pendingCompletion: ((UIImage?) -> Void)?
    @Published var isConfigured = false

    func configure() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isConfigured else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            self.session.commitConfiguration()
            DispatchQueue.main.async { self.isConfigured = true }
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        pendingCompletion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image: UIImage? = {
            guard error == nil, let data = photo.fileDataRepresentation() else { return nil }
            return UIImage(data: data)
        }()
        DispatchQueue.main.async { [weak self] in
            self?.pendingCompletion?(image)
            self?.pendingCompletion = nil
        }
    }
}

/// UIKit bridge for the actual live video preview layer — SwiftUI has no
/// native camera-preview view, this is the standard AVFoundation pattern for it.
struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// Full-screen live camera capture — mirrors the web build's viewfinder:
/// live preview, a sweeping scan-line for "actively inspecting" feedback,
/// a shutter button, and a flash-then-dismiss sequence on capture.
struct CameraViewfinder: View {
    let panelName: String
    var onCapture: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = CameraSessionController()
    @State private var flash = false
    @State private var scanUp = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if controller.isConfigured {
                CameraPreviewLayer(session: controller.session)
                    .ignoresSafeArea()
            }

            // sweeping scan line — purely cosmetic "inspection" feedback while framing the shot
            GeometryReader { geo in
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Color(hex: "FF6A1A"), .clear],
                                          startPoint: .leading, endPoint: .trailing))
                    .frame(height: 2)
                    .shadow(color: Color(hex: "FF6A1A").opacity(0.75), radius: 8)
                    .offset(y: scanUp ? geo.size.height * 0.92 : geo.size.height * 0.08)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: scanUp)
                    .onAppear { scanUp = true }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            Color.white
                .opacity(flash ? 0.85 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.black.opacity(0.4), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                    }
                    Spacer()
                    Text(panelName.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.black.opacity(0.45), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                }
                .padding()

                Spacer()

                Button(action: shoot) {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 4).frame(width: 74, height: 74)
                        Circle().fill(.white).frame(width: 58, height: 58)
                    }
                }
                .disabled(!controller.isConfigured)
                .opacity(controller.isConfigured ? 1 : 0.4)
                .padding(.bottom, 34)
            }
        }
        .onAppear {
            controller.configure()
            controller.start()
        }
        .onDisappear {
            controller.stop()
        }
    }

    private func shoot() {
        flash = true
        controller.capturePhoto { image in
            guard let image else {
                flash = false
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onCapture(image)
                dismiss()
            }
        }
    }
}
