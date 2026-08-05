//
//  ReferenceMarkerDetector.swift
//  DentDOG 2.0
//
//  Auto-detects a physical scale reference in frame — tries a circular
//  magnet marker first (self-aligning to curved/steel panels, preferred),
//  falls back to a rectangular card marker if no circle is found (e.g.
//  aluminum panels where a magnet won't stick).
//
//  Vision has no built-in circle detector, so circular detection is done
//  via contour extraction + circularity scoring.
//

import Vision
import CoreImage
import UIKit

enum ReferenceMarkerType {
    case magnetCircle(diameterMM: Double)   // 25.4mm for a standard 1" magnet
    case cardRectangle(widthMM: Double)     // 85.6mm for ISO/IEC 7810 ID-1
}

struct DetectedMarker {
    let type: ReferenceMarkerType
    let pixelSize: CGFloat        // diameter for circle, width for rectangle
    let centerPixel: CGPoint
    let boundingBox: CGRect       // normalized Vision coordinates (0-1, origin bottom-left)
}

final class ReferenceMarkerDetector {

    var magnetDiameterMM: Double = 25.4   // 1 inch
    var cardWidthMM: Double = 85.6        // ISO/IEC 7810 ID-1

    /// Minimum circularity score (0-1, 1 = perfect circle) to accept a
    /// contour as the magnet marker.
    var circularityThreshold: Double = 0.82

    /// Tries circle (magnet) first, falls back to rectangle (card).
    func detectMarker(
        in pixelBuffer: CVPixelBuffer,
        imageSize: CGSize,
        completion: @escaping (DetectedMarker?) -> Void
    ) {
        detectCircleMarker(in: pixelBuffer, imageSize: imageSize) { [weak self] circleResult in
            if let circleResult = circleResult {
                completion(circleResult)
                return
            }
            self?.detectCardMarker(in: pixelBuffer, imageSize: imageSize) { rectResult in
                completion(rectResult)
            }
        }
    }

    // MARK: - Circle detection (magnet)

    private func detectCircleMarker(
        in pixelBuffer: CVPixelBuffer,
        imageSize: CGSize,
        completion: @escaping (DetectedMarker?) -> Void
    ) {
        let request = VNDetectContoursRequest { [weak self] request, error in
            guard let self = self,
                  let results = request.results as? [VNContoursObservation],
                  let observation = results.first else {
                completion(nil)
                return
            }

            var bestCircle: DetectedMarker?
            var bestScore: Double = 0

            for contour in observation.topLevelContours {
                let points = contour.normalizedPoints
                guard points.count > 8 else { continue }

                let (score, centerNorm, radiusNorm) = self.circularity(of: points)
                guard score >= self.circularityThreshold, score > bestScore else { continue }

                let centerPixel = CGPoint(
                    x: CGFloat(centerNorm.x) * imageSize.width,
                    y: (1 - CGFloat(centerNorm.y)) * imageSize.height
                )
                let diameterPixels = CGFloat(radiusNorm) * 2 * imageSize.width

                bestScore = score
                bestCircle = DetectedMarker(
                    type: .magnetCircle(diameterMM: self.magnetDiameterMM),
                    pixelSize: diameterPixels,
                    centerPixel: centerPixel,
                    boundingBox: CGRect(
                        x: CGFloat(centerNorm.x - radiusNorm),
                        y: CGFloat(centerNorm.y - radiusNorm),
                        width: CGFloat(radiusNorm * 2),
                        height: CGFloat(radiusNorm * 2)
                    )
                )
            }
            completion(bestCircle)
        }

        request.contrastAdjustment = 1.5
        request.detectsDarkOnLight = false // tune per marker color

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    /// Circularity via the isoperimetric inequality: 4π·Area / Perimeter².
    /// A perfect circle scores 1.0. Returns (score, center, averageRadius),
    /// all in normalized coordinates.
    private func circularity(of points: [SIMD2<Float>]) -> (Double, SIMD2<Float>, Float) {
        guard points.count > 2 else { return (0, .zero, 0) }

        var area: Float = 0
        var perimeter: Float = 0
        var centroid = SIMD2<Float>(0, 0)

        for i in 0..<points.count {
            let p1 = points[i]
            let p2 = points[(i + 1) % points.count]
            area += (p1.x * p2.y - p2.x * p1.y)
            perimeter += simd_distance(p1, p2)
            centroid += p1
        }
        area = abs(area) / 2
        centroid /= Float(points.count)

        guard perimeter > 0 else { return (0, centroid, 0) }
        let score = Double(4 * Float.pi * area / (perimeter * perimeter))
        let avgRadius = points.reduce(Float(0)) { $0 + simd_distance($1, centroid) } / Float(points.count)

        return (min(score, 1.0), centroid, avgRadius)
    }

    // MARK: - Rectangle detection (card) — fallback

    private func detectCardMarker(
        in pixelBuffer: CVPixelBuffer,
        imageSize: CGSize,
        completion: @escaping (DetectedMarker?) -> Void
    ) {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            guard let self = self,
                  let results = request.results as? [VNRectangleObservation],
                  let card = results.first else {
                completion(nil)
                return
            }

            let widthNorm = simd_distance(
                SIMD2(Float(card.topLeft.x), Float(card.topLeft.y)),
                SIMD2(Float(card.topRight.x), Float(card.topRight.y))
            )
            let widthPixels = CGFloat(widthNorm) * imageSize.width

            let centerX = (card.topLeft.x + card.topRight.x + card.bottomLeft.x + card.bottomRight.x) / 4
            let centerY = (card.topLeft.y + card.topRight.y + card.bottomLeft.y + card.bottomRight.y) / 4
            let centerPixel = CGPoint(
                x: centerX * imageSize.width,
                y: (1 - centerY) * imageSize.height
            )

            completion(DetectedMarker(
                type: .cardRectangle(widthMM: self.cardWidthMM),
                pixelSize: widthPixels,
                centerPixel: centerPixel,
                boundingBox: card.boundingBox
            ))
        }

        // ID-1 card aspect ratio ~1.586 (85.6/53.98) — rejects non-card
        // rectangles like windows or panel edges.
        request.minimumAspectRatio = 1.45
        request.maximumAspectRatio = 1.75
        request.minimumConfidence = 0.8
        request.maximumObservations = 1

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}
