import SwiftUI
import UIKit

/// Generates a PDF estimate — summary table on page 1, then one full page
/// per captured photo — mirroring the web/Python reportlab version's
/// structure. UIKit has no high-level PDF layout library equivalent to
/// reportlab, so this hand-places text/images with UIGraphicsPDFRenderer.
///
/// HONEST FLAG: column widths and line spacing below are estimated, not
/// measured against a render the way the Python version was (that one was
/// rendered and pixel-checked before shipping; this one can't be, since
/// there's no way to preview a UIGraphicsPDFRenderer output outside Xcode/
/// a real device in this environment). Expect to nudge numbers once you can
/// actually see the output.
enum EstimateExporter {
    private static let pageSize = CGSize(width: 612, height: 792) // US Letter, points
    private static let margin: CGFloat = 40

    static func makePDF(deck: VehicleDeckState) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            drawSummaryPage(ctx: ctx, deck: deck)
            let photoPanels = deck.panels.filter { $0.photo != nil }
            for (i, panel) in photoPanels.enumerated() {
                if let photo = panel.photo {
                    drawPhotoPage(ctx: ctx, panel: panel, photo: photo, index: i + 1, total: photoPanels.count)
                }
            }
        }
    }

    private static func drawSummaryPage(ctx: UIGraphicsPDFRendererContext, deck: VehicleDeckState) {
        ctx.beginPage()
        var y: CGFloat = margin

        draw("DENTDOG · ESTIMATE PREVIEW", at: CGPoint(x: margin, y: y),
             font: .monospacedSystemFont(ofSize: 9, weight: .bold), color: UIColor(hex: "C9550F"))
        y += 18

        draw("Hail Damage Estimate — \(deck.label)", at: CGPoint(x: margin, y: y),
             font: .systemFont(ofSize: 24, weight: .heavy), color: .black)
        y += 30

        draw("\(deck.savedCount)/\(deck.panels.count) panels saved · Date: \(todayString())", at: CGPoint(x: margin, y: y),
             font: .monospacedSystemFont(ofSize: 9, weight: .regular), color: .darkGray)
        y += 30

        // table header
        let cols: [CGFloat] = [margin, margin + 140, margin + 220, margin + 300, margin + 350, margin + 400, margin + 480]
        let headers = ["Panel", "Code", "Bracket", "Size", "OS", "Markups", "Price"]
        let headerFont = UIFont.monospacedSystemFont(ofSize: 8.5, weight: .bold)
        for (i, h) in headers.enumerated() {
            draw(h, at: CGPoint(x: cols[i], y: y), font: headerFont, color: .black)
        }
        y += 14
        strokeLine(from: CGPoint(x: margin, y: y), to: CGPoint(x: pageSize.width - margin, y: y))
        y += 10

        var total = 0
        let rowFont = UIFont.monospacedSystemFont(ofSize: 8.5, weight: .regular)
        for panel in deck.panels where panel.spec.kind == .estimate {
            if y > pageSize.height - margin - 80 {
                ctx.beginPage()
                y = margin
            }
            let bracket = panel.dentBracket?.label ?? "—"
            let size = panel.size?.rawValue ?? "—"
            let markups = panel.markups.isEmpty ? "—" : panel.markups.map(\.rawValue).joined(separator: ", ")
            var priceText = "—"
            var priceColor = UIColor.darkGray
            switch panel.price {
            case .value(let v):
                priceText = "$\(v)"; total += v; priceColor = UIColor(hex: "1C7A45")
            case .conventionalRepair:
                priceText = "CR"; priceColor = UIColor(hex: "A02424")
            case .unavailable:
                priceText = "—"
            }
            let values = [panel.spec.name, panel.spec.code, bracket, size, "\(panel.oversizeCount)", markups]
            for (i, v) in values.enumerated() {
                draw(v, at: CGPoint(x: cols[i], y: y), font: rowFont, color: .darkGray)
            }
            draw(priceText, at: CGPoint(x: cols[6], y: y), font: UIFont.monospacedSystemFont(ofSize: 8.5, weight: .bold), color: priceColor)
            y += 15
        }

        y += 16
        strokeLine(from: CGPoint(x: margin, y: y), to: CGPoint(x: pageSize.width - margin, y: y), width: 1.2)
        y += 12
        draw("PDR ESTIMATE TOTAL", at: CGPoint(x: margin, y: y),
             font: .monospacedSystemFont(ofSize: 11, weight: .bold), color: .black)
        draw("$\(total)", at: CGPoint(x: pageSize.width - margin - 90, y: y - 6),
             font: .systemFont(ofSize: 22, weight: .heavy), color: UIColor(hex: "C9550F"))
    }

    private static func drawPhotoPage(ctx: UIGraphicsPDFRendererContext, panel: PanelState, photo: UIImage, index: Int, total: Int) {
        ctx.beginPage()
        var y: CGFloat = margin

        draw("DENTDOG · ESTIMATE PREVIEW", at: CGPoint(x: margin, y: y),
             font: .monospacedSystemFont(ofSize: 9, weight: .bold), color: UIColor(hex: "C9550F"))
        y += 18

        draw(panel.spec.name, at: CGPoint(x: margin, y: y),
             font: .systemFont(ofSize: 22, weight: .heavy), color: .black)
        y += 28

        let bracket = panel.dentBracket?.label ?? "—"
        let size = panel.size?.rawValue ?? "—"
        var priceText = ""
        if case .value(let v) = panel.price { priceText = " · $\(v)" }
        else if case .conventionalRepair = panel.price { priceText = " · CR" }
        draw("\(panel.spec.code) · \(bracket) dents · \(size)\(priceText) · Photo \(index) of \(total)",
             at: CGPoint(x: margin, y: y), font: .monospacedSystemFont(ofSize: 9, weight: .regular), color: .darkGray)
        y += 20

        let imgWidth = pageSize.width - margin * 2
        let imgHeight = imgWidth * (photo.size.height / max(photo.size.width, 1))
        let imgRect = CGRect(x: margin, y: y, width: imgWidth, height: min(imgHeight, pageSize.height - y - margin))
        photo.draw(in: imgRect)
    }

    // MARK: - drawing helpers

    private static func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        text.draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }

    private static func strokeLine(from: CGPoint, to: CGPoint, width: CGFloat = 0.75) {
        let path = UIBezierPath()
        path.move(to: from)
        path.addLine(to: to)
        path.lineWidth = width
        UIColor.black.setStroke()
        path.stroke()
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd/yyyy"
        return f.string(from: Date())
    }
}

private extension UIColor {
    convenience init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }
}

/// Standard UIActivityViewController bridge — lets the generated PDF Data
/// go through iOS's native share sheet (Save to Files, AirDrop, Mail, etc.)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
