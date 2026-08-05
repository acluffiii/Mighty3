//
//  LiveTrackingController.swift
//  DentDOG 2.0
//
//  Runs the live tracking loop off ARKit frame updates, throttles
//  expensive Vision calls, smooths jittery detections with an
//  exponential moving average, and publishes overlay-ready state
//  for LidarMeasureView to bind to.
//

import ARKit
import SwiftUI
import Combine

// MARK: - Dent-region detector protocol
//
// TODO — the real dent-detection algorithm (Difference of Gaussians)
// already exists and is validated in the web build: see
// detectDentsClassicalCV() in DentDOG.html. That's JavaScript/Canvas-based
// and needs a native Swift port (Core Image / Accelerate/vImage would be
// the natural translation) before this stub can be replaced for real.
// This protocol is the seam where that ported algorithm plugs in —
// everything else in this file is unaware of how dent regions are found.

protocol DentRegionDetecting {
    /// Returns candidate dent bounding boxes in pixel coordinates.
    func detectDentRegions(in pixelBuffer: CVPixelBuffer, imageSize: CGSize) -> [CGRect]
}

/// PLACEHOLDER — returns one fixed box centered in frame so the
/// LiDAR/marker/overlay pipeline is testable before the real DOG
/// algorithm is ported from DentDOG.html. Swap this out in
/// LidarMeasureView's controller init once that port exists.
final class PlaceholderDentRegionDetector: DentRegionDetecting {
    func detectDentRegions(in pixelBuffer: CVPixelBuffer, imageSize: CGSize) -> [CGRect] {
        let w = imageSize.width * 0.16
        return [CGRect(x: imageSize.width * 0.42, y: imageSize.height * 0.38, width: w, height: w)]
    }
}

// MARK: - Overlay state

struct MeasureOverlayState {
    var markerRectNorm: CGRect?
    var dentRectNorm: CGRect?
    var depthFeet: Double?
    var depthConfidence: Float?
}

// MARK: - Exponential moving average smoothing

private struct EMASmoother {
    var alpha: CGFloat = 0.3
    private var smoothed: CGRect?

    mutating func update(with newRect: CGRect?) -> CGRect? {
        guard let newRect = newRect else {
            smoothed = nil
            return nil
        }
        guard let prev = smoothed else {
            smoothed = newRect
            return newRect
        }
        let blended = CGRect(
            x: prev.origin.x + alpha * (newRect.origin.x - prev.origin.x),
            y: prev.origin.y + alpha * (newRect.origin.y - prev.origin.y),
            width: prev.width + alpha * (newRect.width - prev.width),
            height: prev.height + alpha * (newRect.height - prev.height)
        )
        smoothed = blended
        return blended
    }

    mutating func reset() { smoothed = nil }
}

// MARK: - Controller

@MainActor
final class LiveTrackingController: ObservableObject {

    @Published private(set) var overlay = MeasureOverlayState()
    @Published private(set) var isTracking = false

    let lidarManager: LidarDepthManager
    private let markerDetector = ReferenceMarkerDetector()
    private let dentDetector: DentRegionDetecting

    private let frameProcessInterval = 4 // process every 4th ARKit frame
    private var frameCounter = 0

    private var markerSmoother = EMASmoother(alpha: 0.3)
    private var dentSmoother = EMASmoother(alpha: 0.3)
    private var cancellables = Set<AnyCancellable>()

    private var lastDentRectPixels: CGRect?
    private var lastMarker: DetectedMarker?

    init(lidarManager: LidarDepthManager, dentDetector: DentRegionDetecting = PlaceholderDentRegionDetector()) {
        self.lidarManager = lidarManager
        self.dentDetector = dentDetector

        lidarManager.$latestFrame
            .compactMap { $0 }
            .sink { [weak self] frame in self?.process(frame: frame) }
            .store(in: &cancellables)
    }

    func start() {
        isTracking = true
        frameCounter = 0
        markerSmoother.reset()
        dentSmoother.reset()
        lidarManager.startSession()
    }

    func stop() {
        isTracking = false
        lidarManager.stopSession()
        overlay = MeasureOverlayState()
    }

    /// Locks in a measurement from the current tracking state, ready to
    /// apply to a PanelState (size + oversize + provenance fields).
    func capture() -> DentMeasurement {
        guard let dentBoxPixels = lastDentRectPixels,
              let frame = lidarManager.latestFrame else {
            return DentMeasurement(widthMM: nil, heightMM: nil, depthConfidence: nil, measurementMethod: .unmeasured)
        }
        let center = CGPoint(x: dentBoxPixels.midX, y: dentBoxPixels.midY)

        // Priority 1: LiDAR depth-corrected sizing
        if lidarManager.isLidarAvailable,
           let widthMM = lidarManager.realWorldSize(pixelSize: dentBoxPixels.width, atPixel: center, in: frame),
           let heightMM = lidarManager.realWorldSize(pixelSize: dentBoxPixels.height, atPixel: center, in: frame) {
            let confidence = lidarManager.confidenceAtPixel(center, in: frame)
            return DentMeasurement(widthMM: widthMM, heightMM: heightMM, depthConfidence: confidence, measurementMethod: .lidar)
        }

        // Priority 2: reference marker scale (magnet or card)
        if let marker = lastMarker, marker.pixelSize > 0 {
            let mmPerPixel: Double
            switch marker.type {
            case .magnetCircle(let d): mmPerPixel = d / Double(marker.pixelSize)
            case .cardRectangle(let w): mmPerPixel = w / Double(marker.pixelSize)
            }
            return DentMeasurement(
                widthMM: Double(dentBoxPixels.width) * mmPerPixel,
                heightMM: Double(dentBoxPixels.height) * mmPerPixel,
                depthConfidence: nil,
                measurementMethod: .referenceMarker
            )
        }

        return DentMeasurement(widthMM: nil, heightMM: nil, depthConfidence: nil, measurementMethod: .unmeasured)
    }

    private func process(frame: DepthCorrectedFrame) {
        guard isTracking else { return }
        frameCounter += 1
        guard frameCounter % frameProcessInterval == 0 else { return }

        let imageSize = frame.imageResolution
        let dentBoxes = dentDetector.detectDentRegions(in: frame.colorPixelBuffer, imageSize: imageSize)
        let dentBoxPixels = dentBoxes.first
        lastDentRectPixels = dentBoxPixels

        let dentNorm = dentBoxPixels.map { normalize($0, in: imageSize) }
        let smoothedDentNorm = dentSmoother.update(with: dentNorm)

        markerDetector.detectMarker(in: frame.colorPixelBuffer, imageSize: imageSize) { [weak self] marker in
            guard let self = self else { return }
            Task { @MainActor in
                self.lastMarker = marker
                let markerNorm = marker.map { self.normalize($0.boundingBox.toPixelSpace(imageSize: imageSize), in: imageSize) }
                let smoothedMarkerNorm = self.markerSmoother.update(with: markerNorm)

                var depthFeet: Double? = nil
                var confidence: Float? = nil
                if let dentBoxPixels = dentBoxPixels {
                    let center = CGPoint(x: dentBoxPixels.midX, y: dentBoxPixels.midY)
                    if let meters = self.lidarManager.distanceAtPixel(center, in: frame) {
                        depthFeet = Double(meters) * 3.28084
                    }
                    confidence = self.lidarManager.confidenceAtPixel(center, in: frame)
                }

                self.overlay = MeasureOverlayState(
                    markerRectNorm: smoothedMarkerNorm,
                    dentRectNorm: smoothedDentNorm,
                    depthFeet: depthFeet,
                    depthConfidence: confidence
                )
            }
        }
    }

    private func normalize(_ rect: CGRect, in imageSize: CGSize) -> CGRect {
        CGRect(
            x: rect.origin.x / imageSize.width,
            y: rect.origin.y / imageSize.height,
            width: rect.width / imageSize.width,
            height: rect.height / imageSize.height
        )
    }
}

private extension CGRect {
    func toPixelSpace(imageSize: CGSize) -> CGRect {
        CGRect(
            x: origin.x * imageSize.width,
            y: (1 - origin.y - height) * imageSize.height,
            width: width * imageSize.width,
            height: height * imageSize.height
        )
    }
}
