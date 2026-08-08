//
//  DentDoGAnalyzer.swift
//  DentDOG 2.0
//
//  Photo-based dent detection for non-LiDAR devices. Two modes:
//
//  • DoG (Difference of Gaussians) — conceptually ported from
//    detectDentsClassicalCV() in DentDOG.html. Subtracts a coarse Gaussian
//    blur from a fine one; the result peaks at blob-scale dent features.
//    Works best on panels with gloss variation or fine paint texture.
//
//  • Line Board — analyzes distortion of horizontal reference lines
//    reflected off the panel from a PDR dent board. A linear model is fit
//    to each stripe across the frame width; stripes that deviate beyond a
//    threshold mark the dent region.
//
//  Reference-marker scaling: a coin-sized circular highlight in the frame
//  is used as a quarter-equivalent (24.26 mm) scale reference to produce
//  real-world DentMeasurement dimensions. Without one, widthMM/heightMM
//  are nil and the caller shows manual size chips as before.
//

import CoreImage
import UIKit

enum DentDoGAnalyzer {

    // MARK: - Types

    enum MeasureMode { case doG, lineBoard }

    struct AnalysisResult {
        /// Dent bounding box, normalized to image coordinates (0–1, origin top-left).
        let dentBoxNorm: CGRect?
        /// Detected reference circle, normalized. nil if not found.
        let refBoxNorm: CGRect?
        /// Ready-to-apply measurement (widthMM/heightMM are nil when no reference found).
        let measurement: DentMeasurement
        let dentDetected: Bool
    }

    // MARK: - Public

    static func analyze(image: UIImage, mode: MeasureMode) -> AnalysisResult {
        guard let cgImage = bakeOrientation(image) else { return empty(mode) }
        let size = CGSize(width: cgImage.width, height: cgImage.height)

        let dentPx: CGRect?
        switch mode {
        case .doG:       dentPx = runDoG(cgImage: cgImage)
        case .lineBoard: dentPx = runLineBoard(cgImage: cgImage)
        }

        let refPx = detectCoinHighlight(cgImage: cgImage)
        let method: DentMeasurement.MeasurementMethod = mode == .doG ? .photoDoG : .photoLineBoard

        return AnalysisResult(
            dentBoxNorm: dentPx.map { normalized($0, in: size) },
            refBoxNorm: refPx.map { normalized($0, in: size) },
            measurement: buildMeasurement(dent: dentPx, ref: refPx, method: method),
            dentDetected: dentPx != nil
        )
    }

    // MARK: - DoG pipeline

    private static func runDoG(cgImage: CGImage) -> CGRect? {
        let ci = CIImage(cgImage: cgImage)
        let ctx = CIContext(options: [.useSoftwareRenderer: false])

        let gray = ci.applyingFilter("CIColorControls",
                                     parameters: [kCIInputSaturationKey: 0.0,
                                                  kCIInputContrastKey: 1.05])

        // Focus on the center 60% of the frame — tech should aim the dent there.
        let crop = ci.extent.insetBy(dx: ci.extent.width * 0.2, dy: ci.extent.height * 0.2)
        let g = gray.cropped(to: crop)

        // Fine blur (σ=4) captures dent-scale features; coarse (σ=22) is the background.
        let fine   = g.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 4.0])
        let coarse = g.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 22.0])

        // CISubtractBlendMode: result = clamp(inputImage − inputBackgroundImage, 0, 1)
        // fine is inputImage (self), coarse is the background → fine − coarse = DoG.
        let dog = fine.applyingFilter("CISubtractBlendMode",
                                      parameters: [kCIInputBackgroundImageKey: coarse])

        // Amplify, then dilate to fill in sparse edge pixels into a solid region.
        let amp = dog.applyingFilter("CIColorControls",
                                     parameters: [kCIInputContrastKey: 14.0,
                                                  kCIInputBrightnessKey: -0.25])
        let filled = amp.applyingFilter("CIMorphologyMaximum",
                                        parameters: [kCIInputRadiusKey: 10.0])

        guard let rendered = ctx.createCGImage(filled, from: filled.extent),
              let (pix, w, h) = toGray(rendered) else { return nil }

        guard let boxInCrop = brightBB(pix, w, h, threshold: 130) else { return nil }

        // Translate from crop-relative back to full-image pixel coordinates.
        let full = CGRect(x: boxInCrop.origin.x + crop.origin.x,
                          y: boxInCrop.origin.y + crop.origin.y,
                          width: boxInCrop.width, height: boxInCrop.height)

        // Sanity check: reject if detected region is implausibly large (> 40% of image).
        let area = full.width * full.height
        let imageArea = CGFloat(cgImage.width) * CGFloat(cgImage.height)
        guard area < imageArea * 0.40 else { return nil }
        return full
    }

    // MARK: - Line board pipeline

    private static func runLineBoard(cgImage: CGImage) -> CGRect? {
        guard let (pix, w, h) = toGray(cgImage) else { return nil }

        // Sample ~60 columns evenly across the frame.
        let step = max(1, w / 60)
        var centersByCol = [[Int]]()
        for x in Swift.stride(from: 0, to: w, by: step) {
            centersByCol.append(lineCenters(pix, w, h, col: x))
        }

        let maxStripes = centersByCol.map(\.count).max() ?? 0
        guard maxStripes >= 3 else { return nil }

        var minX = w, maxX = 0, minY = h, maxY = 0
        let devThreshold = Double(h) * 0.018   // 1.8% of image height

        for sIdx in 0..<maxStripes {
            var pts = [(Double, Double)]()
            for (ci, centers) in centersByCol.enumerated() where sIdx < centers.count {
                pts.append((Double(ci * step), Double(centers[sIdx])))
            }
            guard pts.count >= 3 else { continue }

            let (slope, intercept) = lineFit(pts)
            for (x, y) in pts {
                guard abs(y - (slope * x + intercept)) > devThreshold else { continue }
                let xi = Int(x), yi = Int(y)
                minX = min(minX, xi); maxX = max(maxX, xi)
                minY = min(minY, yi); maxY = max(maxY, yi)
            }
        }

        guard maxX > minX, maxY > minY else { return nil }
        let pad = max(24, (maxX - minX) / 3)
        return CGRect(
            x: max(0, minX - pad),
            y: max(0, minY - pad),
            width: min(w - max(0, minX - pad), (maxX - minX) + pad * 2),
            height: min(h - max(0, minY - pad), (maxY - minY) + pad * 2)
        )
    }

    // MARK: - Reference coin highlight

    private static func detectCoinHighlight(cgImage: CGImage) -> CGRect? {
        // A coin on a dark panel reflects as a small, very bright circular highlight.
        // Threshold aggressively, then find a bright blob in the coin-size range
        // (3–12% of frame width — coin at a normal shooting distance).
        let ci = CIImage(cgImage: cgImage)
        let ctx = CIContext(options: [.useSoftwareRenderer: false])

        let hot = ci.applyingFilter("CIColorControls",
                                    parameters: [kCIInputSaturationKey: 0.0,
                                                 kCIInputContrastKey: 8.0,
                                                 kCIInputBrightnessKey: -0.6])

        guard let rendered = ctx.createCGImage(hot, from: hot.extent),
              let (pix, w, h) = toGray(rendered),
              let bb = brightBB(pix, w, h, threshold: 210) else { return nil }

        let minPx = Int(Double(w) * 0.03)
        let maxPx = Int(Double(w) * 0.12)
        let dim   = max(Int(bb.width), Int(bb.height))
        guard dim >= minPx, dim <= maxPx else { return nil }
        return bb
    }

    // MARK: - Pixel helpers

    /// Renders cgImage into a single-channel grayscale pixel buffer.
    private static func toGray(_ cgImage: CGImage) -> ([UInt8], Int, Int)? {
        let w = cgImage.width, h = cgImage.height
        var pix = [UInt8](repeating: 0, count: w * h)
        guard let cs  = CGColorSpace(name: CGColorSpace.linearGray),
              let ctx = CGContext(data: &pix, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (pix, w, h)
    }

    /// Bounding box of all pixels ≥ threshold (top-left origin).
    private static func brightBB(_ pix: [UInt8], _ w: Int, _ h: Int, threshold: UInt8) -> CGRect? {
        var x0 = w, x1 = 0, y0 = h, y1 = 0
        for y in 0..<h {
            let row = y * w
            for x in 0..<w where pix[row + x] >= threshold {
                x0 = min(x0, x); x1 = max(x1, x)
                y0 = min(y0, y); y1 = max(y1, y)
            }
        }
        guard x1 > x0, y1 > y0 else { return nil }
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    /// Y-centers of bright horizontal stripes in one pixel column.
    private static func lineCenters(_ pix: [UInt8], _ w: Int, _ h: Int, col: Int) -> [Int] {
        var result = [Int]()
        var inRun = false, runStart = 0
        let minRun = max(2, h / 60)
        for y in 0..<h {
            let bright = pix[y * w + col] > 130
            if bright, !inRun  { runStart = y; inRun = true }
            if !bright, inRun  {
                if y - runStart >= minRun { result.append((runStart + y) / 2) }
                inRun = false
            }
        }
        if inRun, h - runStart >= minRun { result.append((runStart + h) / 2) }
        return result
    }

    // MARK: - Math

    private static func lineFit(_ pts: [(Double, Double)]) -> (Double, Double) {
        let n = Double(pts.count)
        let sX  = pts.map(\.0).reduce(0, +), sY  = pts.map(\.1).reduce(0, +)
        let sXY = pts.map { $0.0 * $0.1 }.reduce(0, +)
        let sXX = pts.map { $0.0 * $0.0 }.reduce(0, +)
        let d = n * sXX - sX * sX
        guard d != 0 else { return (0, sY / n) }
        let m = (n * sXY - sX * sY) / d
        return (m, (sY - m * sX) / n)
    }

    private static func normalized(_ r: CGRect, in s: CGSize) -> CGRect {
        CGRect(x: r.origin.x / s.width,  y: r.origin.y / s.height,
               width: r.width / s.width, height: r.height / s.height)
    }

    // MARK: - Measurement builder

    private static func buildMeasurement(dent: CGRect?, ref: CGRect?,
                                          method: DentMeasurement.MeasurementMethod) -> DentMeasurement {
        guard let dent, let ref, ref.width > 0 else {
            return DentMeasurement(widthMM: nil, heightMM: nil,
                                   depthConfidence: nil, measurementMethod: method)
        }
        // Treat detected reference circle as a quarter (24.26 mm diameter).
        let mmPerPx = CoinDiameterMM.quarter / Double(ref.width)
        return DentMeasurement(widthMM: Double(dent.width) * mmPerPx,
                               heightMM: Double(dent.height) * mmPerPx,
                               depthConfidence: nil, measurementMethod: method)
    }

    /// Renders UIImage orientation into pixel data so coordinates match what the user sees.
    private static func bakeOrientation(_ image: UIImage) -> CGImage? {
        let sz = image.size
        return UIGraphicsImageRenderer(size: sz).image { _ in
            image.draw(in: CGRect(origin: .zero, size: sz))
        }.cgImage
    }

    private static func empty(_ mode: MeasureMode) -> AnalysisResult {
        let m: DentMeasurement.MeasurementMethod = mode == .doG ? .photoDoG : .photoLineBoard
        return AnalysisResult(
            dentBoxNorm: nil, refBoxNorm: nil,
            measurement: DentMeasurement(widthMM: nil, heightMM: nil,
                                         depthConfidence: nil, measurementMethod: m),
            dentDetected: false
        )
    }
}
