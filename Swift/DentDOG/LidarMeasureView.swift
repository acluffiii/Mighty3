//
//  LidarMeasureView.swift
//  DentDOG 2.0
//
//  The on-screen LiDAR + marker measurement flow, presented as a
//  full-screen cover from PanelStackView the same way CameraViewfinder is.
//  On capture, hands back a photo + measured DentMeasurement so the
//  caller can apply it to a PanelState (suggested size, photo, etc.)
//
//  NOTE: colors reuse the same hex values as PanelCardView/PanelStackView
//  (Color(hex: "FF6A1A") etc.) so this reads as part of the same app,
//  not a bolted-on feature. Color(hex:) is defined once, in PanelCardView.swift.
//

import SwiftUI
import ARKit

struct ARCameraView: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session = session
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()
        return view
    }
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

struct LidarMeasureView: View {
    let panelName: String
    /// Called with (snapshot photo, measurement) once the user captures.
    var onMeasured: (UIImage?, DentMeasurement) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var lidarManager = LidarDepthManager()
    @StateObject private var tracking: LiveTrackingController
    @State private var showNoLidarNotice = false

    init(panelName: String, onMeasured: @escaping (UIImage?, DentMeasurement) -> Void) {
        self.panelName = panelName
        self.onMeasured = onMeasured
        let manager = LidarDepthManager()
        _lidarManager = StateObject(wrappedValue: manager)
        _tracking = StateObject(wrappedValue: LiveTrackingController(lidarManager: manager))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ARCameraView(session: lidarManager.session(shared: true))
                .ignoresSafeArea()

            GeometryReader { geo in
                overlayLayer(in: geo.size)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                topBar
                Spacer()
                if !lidarManager.isLidarAvailable {
                    noLidarBanner
                }
                controls
            }
        }
        .onAppear {
            if !lidarManager.isLidarAvailable { showNoLidarNotice = true }
        }
        .onDisappear { tracking.stop() }
    }

    // MARK: Subviews

    private var topBar: some View {
        HStack {
            Button(action: { tracking.stop(); dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.4), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
            }
            Spacer()
            Text("MEASURE · \(panelName.uppercased())")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.black.opacity(0.45), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
            Spacer()
            if tracking.isTracking {
                liveBadge
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
        }
        .padding()
    }

    private var liveBadge: some View {
        HStack(spacing: 5) {
            Circle().fill(Color(hex: "39D97A")).frame(width: 6, height: 6)
            Text("LIVE").font(.system(size: 9.5, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(Color(hex: "39D97A"))
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.black.opacity(0.5), in: Capsule())
    }

    private var noLidarBanner: some View {
        Text("No LiDAR on this device — using marker-scale fallback. Place the 1\" magnet or a card near the dent.")
            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(10)
            .background(Color(hex: "FF6A1A").opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
    }

    private func overlayLayer(in size: CGSize) -> some View {
        ZStack {
            if let markerRect = tracking.overlay.markerRectNorm {
                let r = denorm(markerRect, in: size)
                Circle()
                    .stroke(Color(hex: "FF6A1A"), lineWidth: 2)
                    .frame(width: r.width, height: r.height)
                    .position(x: r.midX, y: r.midY)
                Text("REF")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color(hex: "FF6A1A"))
                    .position(x: r.midX, y: r.midY + r.height / 2 + 12)
            }

            if let dentRect = tracking.overlay.dentRectNorm {
                let r = denorm(dentRect, in: size)
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "39D97A"), lineWidth: 2)
                    .frame(width: r.width, height: r.height)
                    .position(x: r.midX, y: r.midY)
            }

            if let depthFeet = tracking.overlay.depthFeet {
                Text(String(format: "DEPTH · %.2fft", depthFeet))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Color(hex: "39D97A"))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .position(x: 70, y: 90)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Button(action: toggleTracking) {
                Text(tracking.isTracking ? "Stop tracking" : "Start live tracking")
                    .font(.system(size: 14.5, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .background(tracking.isTracking ? Color.white.opacity(0.12) : Color(hex: "FF6A1A"))
            .foregroundStyle(tracking.isTracking ? .white : .black)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if tracking.isTracking {
                Button(action: doCapture) {
                    Text("Capture measurement")
                        .font(.system(size: 14.5, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .background(Color(hex: "39D97A"))
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .padding(.bottom, 20)
    }

    // MARK: Actions

    private func toggleTracking() {
        if tracking.isTracking {
            tracking.stop()
        } else {
            tracking.start()
        }
    }

    private func doCapture() {
        let measurement = tracking.capture()
        let snapshot = lidarManager.session(shared: true).currentFrame.flatMap { arFrame -> UIImage? in
            let ciImage = CIImage(cvPixelBuffer: arFrame.capturedImage)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
            return UIImage(cgImage: cgImage)
        }
        tracking.stop()
        onMeasured(snapshot, measurement)
        dismiss()
    }

    private func denorm(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: rect.origin.x * size.width,
            y: rect.origin.y * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }
}
