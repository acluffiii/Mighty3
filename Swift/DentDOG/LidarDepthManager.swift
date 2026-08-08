//
//  LidarDepthManager.swift
//  DentDOG 2.0
//
//  Captures synchronized color + LiDAR depth frames and exposes
//  real-world distance-to-panel data for dent size correction.
//
//  Requires: iPhone 12 Pro or later (Pro models with LiDAR scanner).
//  On non-LiDAR devices, isLidarAvailable is false and the app should
//  fall back to ReferenceMarkerDetector-only scaling (see
//  DentMeasurementService).
//

import ARKit
import simd

/// Represents a single captured frame with everything needed
/// to convert pixel measurements into real-world measurements.
struct DepthCorrectedFrame {
    let colorPixelBuffer: CVPixelBuffer
    let depthMap: CVPixelBuffer          // Float32 depth values in meters
    let confidenceMap: CVPixelBuffer?    // Per-pixel confidence (0=low, 1=med, 2=high)
    let cameraIntrinsics: simd_float3x3  // fx, fy, cx, cy packed in matrix form
    let imageResolution: CGSize
}

final class LidarDepthManager: NSObject, ObservableObject {

    /// Static check so call sites (e.g. PanelStackView) can route without
    /// instantiating a full LidarDepthManager or importing ARKit themselves.
    static var isLidarCapable: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    @Published private(set) var isLidarAvailable: Bool = false
    @Published private(set) var latestFrame: DepthCorrectedFrame?
    @Published private(set) var statusMessage: String = "Not started"

    private let arSession = ARSession()

    override init() {
        super.init()
        isLidarAvailable = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        arSession.delegate = self
    }

    /// Exposes the underlying ARSession for SwiftUI's ARCameraView to
    /// render the live feed. `shared` is a no-op flag kept for call-site
    /// clarity — there's only ever one session per manager instance.
    func session(shared: Bool = true) -> ARSession { arSession }

    func startSession() {
        guard isLidarAvailable else {
            statusMessage = "This device has no LiDAR scanner — falling back to reference-marker mode."
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = .sceneDepth
        config.planeDetection = []
        arSession.run(config, options: [.resetTracking, .removeExistingAnchors])
        statusMessage = "Scanning..."
    }

    func stopSession() {
        arSession.pause()
    }

    /// Real-world distance (meters) from camera to a given pixel location
    /// in the color image. Returns nil if depth data unavailable at that point.
    func distanceAtPixel(_ point: CGPoint, in frame: DepthCorrectedFrame) -> Float? {
        let depthMap = frame.depthMap
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        let scaleX = CGFloat(width) / frame.imageResolution.width
        let scaleY = CGFloat(height) / frame.imageResolution.height
        let dx = Int(point.x * scaleX)
        let dy = Int(point.y * scaleY)

        guard dx >= 0, dx < width, dy >= 0, dy < height else { return nil }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let rowStride = bytesPerRow / MemoryLayout<Float32>.size
        let depthValue = floatBuffer[dy * rowStride + dx]

        return depthValue.isFinite ? depthValue : nil
    }

    /// Converts a measured pixel span (e.g. dent width/height detected by
    /// your DoG pipeline) into real-world millimeters, corrected for
    /// distance-to-panel at that location.
    func realWorldSize(
        pixelSize: CGFloat,
        atPixel point: CGPoint,
        in frame: DepthCorrectedFrame
    ) -> Double? {
        guard let depthMeters = distanceAtPixel(point, in: frame), depthMeters > 0 else {
            return nil
        }
        let fx = frame.cameraIntrinsics.columns.0.x
        let fy = frame.cameraIntrinsics.columns.1.y
        let focalLengthPixels = (fx + fy) / 2.0

        let sizeMeters = (Double(pixelSize) * Double(depthMeters)) / Double(focalLengthPixels)
        return sizeMeters * 1000.0 // millimeters
    }

    /// Confidence check — average confidence (0=low, 1=medium, 2=high) in a
    /// small window around the pixel, or nil if no confidence map available.
    func confidenceAtPixel(_ point: CGPoint, in frame: DepthCorrectedFrame, windowSize: Int = 3) -> Float? {
        guard let confidenceMap = frame.confidenceMap else { return nil }
        CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }

        let width = CVPixelBufferGetWidth(confidenceMap)
        let height = CVPixelBufferGetHeight(confidenceMap)
        let scaleX = CGFloat(width) / frame.imageResolution.width
        let scaleY = CGFloat(height) / frame.imageResolution.height
        let cx = Int(point.x * scaleX)
        let cy = Int(point.y * scaleY)

        guard let baseAddress = CVPixelBufferGetBaseAddress(confidenceMap) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(confidenceMap)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        var total: Float = 0
        var count: Float = 0
        let half = windowSize / 2
        for y in (cy - half)...(cy + half) {
            for x in (cx - half)...(cx + half) {
                guard x >= 0, x < width, y >= 0, y < height else { continue }
                total += Float(buffer[y * bytesPerRow + x])
                count += 1
            }
        }
        return count > 0 ? total / count : nil
    }
}

extension LidarDepthManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let sceneDepth = frame.sceneDepth else { return }
        let corrected = DepthCorrectedFrame(
            colorPixelBuffer: frame.capturedImage,
            depthMap: sceneDepth.depthMap,
            confidenceMap: sceneDepth.confidenceMap,
            cameraIntrinsics: frame.camera.intrinsics,
            imageResolution: CGSize(
                width: CVPixelBufferGetWidth(frame.capturedImage),
                height: CVPixelBufferGetHeight(frame.capturedImage)
            )
        )
        DispatchQueue.main.async { self.latestFrame = corrected }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.statusMessage = "AR session error: \(error.localizedDescription)"
        }
    }
}
