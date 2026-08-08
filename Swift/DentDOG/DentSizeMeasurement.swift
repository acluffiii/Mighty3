//
//  DentSizeMeasurement.swift
//  DentDOG 2.0
//
//  Bridges LiDAR/marker-measured real-world sizes (mm) to the app's
//  existing DentSize enum (Models.swift), using actual US coin diameters —
//  the same names the DentSize cases are already based on.
//

import Foundation

/// Real diameters of the US coins DentSize is named after (mm).
/// Source: US Mint official specifications.
enum CoinDiameterMM {
    static let dime: Double = 17.91
    static let nickel: Double = 21.21
    static let quarter: Double = 24.26
    static let halfDollar: Double = 30.61
}

extension DentSize {
    /// Reference diameter in mm for this bucket.
    var referenceDiameterMM: Double {
        switch self {
        case .dime: return CoinDiameterMM.dime
        case .nickel: return CoinDiameterMM.nickel
        case .quarter: return CoinDiameterMM.quarter
        case .half: return CoinDiameterMM.halfDollar
        }
    }

    /// Finds the closest DentSize bucket for a measured diameter (mm),
    /// by nearest-neighbor on the real coin diameters. Measurements
    /// larger than a half-dollar still return .half — DentDOG's oversize
    /// workflow (PanelState.oversizeCount) handles anything beyond that,
    /// it's not a new DentSize case.
    static func nearest(toDiameterMM diameterMM: Double) -> DentSize {
        DentSize.allCases.min(by: { a, b in
            abs(a.referenceDiameterMM - diameterMM) < abs(b.referenceDiameterMM - diameterMM)
        }) ?? .dime
    }
}

/// One completed LiDAR/marker measurement, ready to apply to a PanelState.
struct DentMeasurement {
    let widthMM: Double?
    let heightMM: Double?
    let depthConfidence: Float?      // 0-2 scale (ARKit sceneDepth confidence), nil if unavailable
    let measurementMethod: MeasurementMethod

    enum MeasurementMethod: String {
        case lidar = "LiDAR"
        case referenceMarker = "Marker scale"
        case photoDoG = "Photo (DoG)"
        case photoLineBoard = "Photo (Lines)"
        case unmeasured = "Unmeasured"
    }

    /// Average of width/height, used as the "diameter" for DentSize matching.
    var averageDiameterMM: Double? {
        guard let w = widthMM, let h = heightMM else { return widthMM ?? heightMM }
        return (w + h) / 2
    }

    var suggestedSize: DentSize? {
        guard let d = averageDiameterMM else { return nil }
        return DentSize.nearest(toDiameterMM: d)
    }

    func formatted(useImperial: Bool = true) -> String {
        guard let w = widthMM, let h = heightMM else { return "Unmeasured" }
        if useImperial {
            return String(format: "%.2fin × %.2fin", w / 25.4, h / 25.4)
        }
        return String(format: "%.1fmm × %.1fmm", w, h)
    }
}
