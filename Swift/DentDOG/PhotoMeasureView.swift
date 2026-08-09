//
//  PhotoMeasureView.swift
//  DentDOG 2.0
//
//  Full-screen dent measurement for non-LiDAR iPhones. Three capture modes:
//
//    • DoG       — single camera, direct panel photo; blob detection.
//    • Line      — single camera, PDR board reflection; stripe distortion.
//    • Dual Cam  — simultaneous wide + ultrawide (A12+ only); stereo line board.
//                  Consensus detection filters noise; disparity encodes depth.
//
//  After capture, analysis runs on a background thread. The review screen
//  overlays a green dent box and orange reference coin circle (if detected).
//

import SwiftUI
import AVFoundation

struct PhotoMeasureView: View {
    let panelName: String
    var onMeasured: (UIImage?, DentMeasurement) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera     = CameraSessionController()
    @StateObject private var dualCamera = DualCameraLineController()

    @State private var captureMode: CaptureMode = .doG
    @State private var dualConfigured   = false
    @State private var capturedImage: UIImage?
    @State private var result: DentDoGAnalyzer.AnalysisResult?

    private enum CaptureMode {
        case doG, lineBoard, dualLineBoard
        var isDual: Bool { self == .dualLineBoard }
    }

    var body: some View {
        ZStack {
            Color(hex: "14171A").ignoresSafeArea()

            if let image = capturedImage {
                if let r = result {
                    reviewScreen(image: image, result: r)
                } else {
                    analyzingSpinner
                }
            } else {
                captureScreen
            }
        }
        .onAppear {
            camera.configure()
            camera.start()
        }
        .onDisappear {
            camera.stop()
            dualCamera.stop()
        }
        .onChange(of: captureMode) { _, newMode in
            if newMode.isDual {
                camera.stop()
                if dualConfigured {
                    dualCamera.start()
                } else {
                    dualCamera.configure()
                    dualConfigured = true
                }
            } else {
                dualCamera.stop()
                camera.start()
            }
        }
    }

    // MARK: - Capture screen

    private var captureScreen: some View {
        VStack(spacing: 0) {
            topBar(retakeMode: false)
            Spacer()
            VStack(spacing: 12) {
                modeToggle
                instructionCard
            }
            .padding(.horizontal)
            .padding(.bottom, 16)

            cameraPreview
                .padding(.horizontal)

            Spacer()
            captureButton
                .padding(.bottom, 30)
        }
    }

    private var cameraPreview: some View {
        Group {
            if captureMode.isDual {
                if dualCamera.isReady {
                    CameraPreviewLayer(session: dualCamera.session)
                } else {
                    previewPlaceholder
                }
            } else {
                if camera.isConfigured {
                    CameraPreviewLayer(session: camera.session)
                } else {
                    previewPlaceholder
                }
            }
        }
        .aspectRatio(3/4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var previewPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06))
            VStack(spacing: 10) {
                ProgressView().tint(.white)
                if captureMode.isDual, !DualCameraLineController.isSupported {
                    Text("Multi-cam not supported on this device")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(hex: "FF6A1A"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
            }
        }
    }

    // MARK: - Review screen

    private func reviewScreen(image: UIImage, result: DentDoGAnalyzer.AnalysisResult) -> some View {
        VStack(spacing: 0) {
            topBar(retakeMode: true)

            GeometryReader { geo in
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    detectionOverlay(result: result, image: image, viewSize: geo.size)
                }
            }
            .clipped()

            VStack(spacing: 12) {
                measurementCard(result)
                useMeasurementButton(image: image, result: result)
            }
            .padding()
            .background(Color(hex: "14171A"))
        }
    }

    // MARK: - Sub-views

    private func topBar(retakeMode: Bool) -> some View {
        HStack {
            if retakeMode {
                Button { retake() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Retake")
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(.white.opacity(0.1), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.2)))
                }
            } else {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.black.opacity(0.4), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                }
            }
            Spacer()
            Text("PHOTO MEASURE · \(panelName.uppercased())")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.black.opacity(0.45), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
        .padding()
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeChip("DoG detect", sel: captureMode == .doG) { captureMode = .doG }
            modeChip("Line board", sel: captureMode == .lineBoard) { captureMode = .lineBoard }
            if DualCameraLineController.isSupported {
                modeChip("Dual Cam", sel: captureMode == .dualLineBoard) { captureMode = .dualLineBoard }
            }
        }
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.12)))
    }

    private func modeChip(_ label: String, sel: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(sel ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(sel ? Color(hex: "FF6A1A") : Color.clear,
                             in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .padding(2)
    }

    private var instructionCard: some View {
        let text: String
        switch captureMode {
        case .doG:
            text = "Center the dent in frame. Place a quarter near it for auto-scale."
        case .lineBoard:
            text = "Aim at the PDR board reflection on the panel — distorted stripes show the dent."
        case .dualLineBoard:
            text = "Aim both cameras at the line board reflection. Wide + ultrawide stereo confirms the dent and estimates depth."
        }
        return Text(text)
            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.center)
            .padding(10)
            .background(Color(hex: "FF6A1A").opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
    }

    private var captureButton: some View {
        let ready = captureMode.isDual ? dualCamera.isReady : camera.isConfigured
        return Button(action: shootAndAnalyze) {
            Text("Capture & Analyze")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(ready ? Color(hex: "FF6A1A") : Color.gray,
                             in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!ready)
        .padding(.horizontal)
    }

    private var analyzingSpinner: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color(hex: "FF6A1A"))
                .scaleEffect(1.4)
            Text("Analyzing image…")
                .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    @ViewBuilder
    private func detectionOverlay(result: DentDoGAnalyzer.AnalysisResult,
                                   image: UIImage, viewSize: CGSize) -> some View {
        let display = imageDisplayRect(imageSize: image.size, viewSize: viewSize)

        if let dn = result.dentBoxNorm {
            let r = mapNorm(dn, display: display)
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "39D97A"), lineWidth: 2.5)
                .frame(width: r.width, height: r.height)
                .position(x: r.midX, y: r.midY)
            Text("DENT")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "39D97A"))
                .padding(.horizontal, 5).padding(.vertical, 3)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .position(x: r.midX, y: max(12, r.minY - 12))
        }

        if let rn = result.refBoxNorm {
            let r = mapNorm(rn, display: display)
            Circle()
                .stroke(Color(hex: "FF6A1A"), lineWidth: 2)
                .frame(width: r.width, height: r.height)
                .position(x: r.midX, y: r.midY)
            Text("REF")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "FF6A1A"))
                .padding(.horizontal, 5).padding(.vertical, 3)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .position(x: r.midX, y: max(12, r.minY - 12))
        }
    }

    @ViewBuilder
    private func measurementCard(_ result: DentDoGAnalyzer.AnalysisResult) -> some View {
        let m = result.measurement
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(m.measurementMethod.rawValue, systemImage: "camera.viewfinder")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: "FF6A1A"))
                Spacer()
                if result.dentDetected {
                    Label("Dent detected", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(hex: "39D97A"))
                } else {
                    Label("No region found", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(hex: "FF6A1A"))
                }
            }

            if let conf = m.depthConfidence {
                HStack(spacing: 6) {
                    Text("Depth confidence:")
                        .foregroundStyle(.white.opacity(0.6))
                    Text(String(format: "%.0f%%", conf * 100))
                        .foregroundStyle(conf > 0.5 ? Color(hex: "39D97A") : Color(hex: "FF6A1A"))
                        .fontWeight(.bold)
                }
                .font(.system(size: 12, design: .monospaced))
            }

            if let suggested = m.suggestedSize {
                HStack(spacing: 6) {
                    Text("Suggested size:")
                        .foregroundStyle(.white.opacity(0.6))
                    Text(suggested.rawValue)
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                    Text("(\(m.formatted()))")
                        .foregroundStyle(Color(hex: "39D97A"))
                }
                .font(.system(size: 13, design: .monospaced))
            } else {
                Text(result.dentDetected
                     ? "Place a quarter near the dent and retake for auto-sizing."
                     : "Try adjusting lighting or angle, then retake.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
    }

    private func useMeasurementButton(image: UIImage, result: DentDoGAnalyzer.AnalysisResult) -> some View {
        Button {
            onMeasured(image, result.measurement)
            dismiss()
        } label: {
            Text(result.dentDetected ? "Use this measurement" : "Use photo (manual sizing)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(result.dentDetected ? Color.black : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    result.dentDetected
                        ? Color(hex: "39D97A")
                        : Color.white.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func shootAndAnalyze() {
        if captureMode.isDual {
            dualCamera.capture { wideImg, ultraImg, fovRatio in
                self.capturedImage = wideImg
                DispatchQueue.global(qos: .userInitiated).async {
                    let r = DentDoGAnalyzer.analyzeStereoLineBoard(
                        wide: wideImg, ultra: ultraImg, fovRatio: fovRatio)
                    DispatchQueue.main.async { self.result = r }
                }
            }
        } else {
            let analyzerMode: DentDoGAnalyzer.MeasureMode = captureMode == .doG ? .doG : .lineBoard
            camera.capturePhoto { image in
                guard let image else { return }
                self.capturedImage = image
                DispatchQueue.global(qos: .userInitiated).async {
                    let r = DentDoGAnalyzer.analyze(image: image, mode: analyzerMode)
                    DispatchQueue.main.async { self.result = r }
                }
            }
        }
    }

    private func retake() {
        capturedImage = nil
        result = nil
        if captureMode.isDual {
            dualCamera.start()
        } else {
            camera.start()
        }
    }

    // MARK: - Coordinate helpers

    private func imageDisplayRect(imageSize: CGSize, viewSize: CGSize) -> CGRect {
        let ia = imageSize.width / imageSize.height
        let va = viewSize.width / viewSize.height
        if ia > va {
            let h = viewSize.width / ia
            return CGRect(x: 0, y: (viewSize.height - h) / 2, width: viewSize.width, height: h)
        } else {
            let w = viewSize.height * ia
            return CGRect(x: (viewSize.width - w) / 2, y: 0, width: w, height: viewSize.height)
        }
    }

    private func mapNorm(_ norm: CGRect, display: CGRect) -> CGRect {
        CGRect(
            x: display.origin.x + norm.origin.x * display.width,
            y: display.origin.y + norm.origin.y * display.height,
            width: norm.width  * display.width,
            height: norm.height * display.height
        )
    }
}
