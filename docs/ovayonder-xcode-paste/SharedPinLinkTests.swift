import XCTest
@testable import OvaYonderCore

final class SharedPinLinkTests: XCTestCase {
    private let downtown = Coordinate(latitude: 29.7604, longitude: -95.3698)

    func testWebURLFormat() {
        let url = SharedPinLink.webURL(for: SharedPin(coordinate: downtown, name: "Downtown Houston"))
        XCTAssertEqual(url.absoluteString, "https://ovayonder.sunovabit.org/p/?lat=29.7604&lng=-95.3698&name=Downtown%20Houston")
        let noName = SharedPinLink.webURL(for: SharedPin(coordinate: downtown, name: nil))
        XCTAssertEqual(noName.absoluteString, "https://ovayonder.sunovabit.org/p/?lat=29.7604&lng=-95.3698")
    }

    func testRoundTripKeepsAwkwardNames() {
        for name in ["Downtown Houston", "A&B=C+D", "Café Ñandú 🍔", "50% off? #1", "<script>alert(1)</script>"] {
            let url = SharedPinLink.webURL(for: SharedPin(coordinate: downtown, name: name))
            let pin = SharedPinLink.pin(from: url)
            XCTAssertEqual(pin?.name, name, url.absoluteString)
            XCTAssertEqual(pin?.coordinate, downtown)
        }
    }

    func testReadsAllLinkForms() throws {
        let forms = [
            "https://ovayonder.sunovabit.org/p/?lat=29.7604&lng=-95.3698&name=Downtown%20Houston",
            "https://ovayonder.sunovabit.org/p?lat=29.7604&lng=-95.3698&name=Downtown%20Houston",
            "https://OvaYonder.Sunovabit.org/p/?lat=29.7604&lng=-95.3698&name=Downtown+Houston",
            "ovayonder://p?lat=29.7604&lng=-95.3698&name=Downtown%20Houston",
        ]
        for text in forms {
            let pin = SharedPinLink.pin(from: try XCTUnwrap(URL(string: text)))
            XCTAssertEqual(pin?.coordinate, downtown, text)
            XCTAssertEqual(pin?.name, "Downtown Houston", text)
        }
        let literalPlus = SharedPinLink.pin(from: URL(string: "https://ovayonder.sunovabit.org/p/?lat=1&lng=2&name=A%2BB")!)
        XCTAssertEqual(literalPlus?.name, "A+B")
    }

    func testRejectsBadCoordinates() {
        let bad = [
            "", "?lng=2", "?lat=1", "?lat=abc&lng=2", "?lat=999&lng=2", "?lat=1&lng=-181", "?lat=90.0001&lng=0",
            "?lat=1e1&lng=2", "?lat=0x10&lng=2", "?lat=Infinity&lng=2", "?lat=NaN&lng=2", "?lat=.&lng=2", "?lat=--1&lng=2", "?lat=1.2.3&lng=2",
        ]
        for query in bad {
            XCTAssertNil(SharedPinLink.pin(from: URL(string: "https://ovayonder.sunovabit.org/p/" + query)!), query)
        }
        XCTAssertNotNil(SharedPinLink.pin(from: URL(string: "https://ovayonder.sunovabit.org/p/?lat=-90&lng=180")!))
        XCTAssertNotNil(SharedPinLink.pin(from: URL(string: "https://ovayonder.sunovabit.org/p/?lat=+.5&lng=-0")!))
    }

    func testOtherLinksAreNotPins() {
        XCTAssertNil(SharedPinLink.pin(from: URL(string: "https://example.com/p/?lat=1&lng=2")!))
        XCTAssertNil(SharedPinLink.pin(from: URL(string: "https://ovayonder.sunovabit.org/eta/abc123def456")!))
        XCTAssertNil(SharedPinLink.pin(from: URL(string: "https://ovayonder.sunovabit.org/px/?lat=1&lng=2")!))
        XCTAssertNil(SharedPinLink.pin(from: LiveShareLink.appURL(token: "abc123")))
        // And a pin link is never mistaken for a live ETA.
        XCTAssertNil(LiveShareLink.token(from: SharedPinLink.webURL(for: SharedPin(coordinate: downtown, name: "eta"))))
    }

    func testNameCleaning() {
        XCTAssertNil(SharedPinLink.cleanName(nil))
        XCTAssertNil(SharedPinLink.cleanName("   \n\t "))
        XCTAssertEqual(SharedPinLink.cleanName("  Two\n lines\u{202E}and\u{200B}hidden  "), "Two lines and hidden")
        let long = String(repeating: "A", count: 120)
        let cleaned = SharedPinLink.cleanName(long)
        XCTAssertEqual(cleaned?.count, 80)
        XCTAssertEqual(cleaned?.hasSuffix("…"), true)
        XCTAssertEqual(SharedPin(coordinate: downtown, name: "").title, "Shared location")
    }

    func testDegreesText() {
        XCTAssertEqual(SharedPinLink.degreesText(29.7604), "29.7604")
        XCTAssertEqual(SharedPinLink.degreesText(-95.369812345), "-95.369812")
        XCTAssertEqual(SharedPinLink.degreesText(0), "0")
        XCTAssertEqual(SharedPinLink.degreesText(-0.0000001), "0")
    }
}
