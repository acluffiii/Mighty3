# DentDOG
*(formerly HailDeck — renamed to tie together the app name and the DOG/Difference-of-Gaussians dent-detection feature)*

Standalone SwiftUI app — separate codebase from Dent Dial. Same estimating niche
(hail damage, panel-by-panel), different product.

## Rename scope — completed

Full rename from HailDeck to DentDOG: UI text, PDF headers, exported filenames,
app icon, Keychain/UserDefaults keys, OAuth redirect URL scheme (`dentdog://...`),
`NSCameraUsageDescription`, `manifest.json` name/short_name on the web build,
source folder (`DentDOG/`), entry point (`DentDOGApp.swift`), XcodeGen project
and target name (`DentDOG`), and Codemagic workflow/scheme/artifact references.

The bundle identifier (`com.cluffwork.haildeck`) was intentionally left as-is —
changing a bundle ID breaks the App Store record, TestFlight builds, and any
existing device installs. Rename it in Xcode's Signing & Capabilities tab only
when you're ready to treat it as a new App Store listing.

## What's here

- `DentDOGApp.swift` — entry point
- `Models.swift` — 20-card deck model, `DentBracket`, the exact-rule pricing
  engine (`Pricing` enum), and `VehicleDeckState` (wraps one vehicle's full deck
  so the app can hold two and switch between them)
- `PanelStackView.swift` — the deck: axis-locked shuffle/pivot gesture, double-tap
  capture, deck order persistence, tilt-then-swipe vehicle switching, panel map
  + PDF export buttons
- `PanelCardView.swift` — two card layouts (estimate vs. doc-only), price line,
  CR display, red/green status glow, the hidden spine
- `VehicleMapView.swift` — the vector vehicle diagram, tap-to-jump
- `CameraViewfinder.swift` — live in-app camera preview (AVFoundation), scan-line
  overlay, shutter button — replaces the native picker as the primary capture flow
- `CameraCapture.swift` — the old `UIImagePickerController` wrapper. No longer
  wired into the app (superseded by `CameraViewfinder.swift`); left in the project
  in case you ever want the simpler native-picker flow back as a fallback
- `EstimateExporter.swift` — PDF generation (`UIGraphicsPDFRenderer`) + a
  `ShareSheet` wrapper so the PDF goes through iOS's native share sheet
- `OAuthClient.swift` — OAuth 2.0 client (Authorization Code + PKCE via
  `ASWebAuthenticationSession`) configured for both Mitchell and CCC, plus
  Keychain-backed token storage
- `InsurerConnectView.swift` — Connect/Disconnect UI for each provider
- `PhotoImporter.swift` — photo library import via `PHPickerViewController`,
  wired to a header-level "Import Photo" button (targets whichever panel is
  currently on top of the front deck — same fix pattern as the web build,
  after a per-card version turned out to be hard to spot on a real device)

## Insurer integration (Mitchell / CCC) — what's real vs. what's a placeholder

`OAuthClient.swift` is a fully functional OAuth 2.0 client — real PKCE, real
`ASWebAuthenticationSession` sign-in flow, real Keychain token persistence,
real token refresh. What's **not** real: the `clientID` values and exact
endpoint URLs in `InsurerProvider.mitchell` / `InsurerProvider.ccc`, since
those only exist once DentDOG is actually registered with each provider:

- **Mitchell**: has a public developer portal (developer.mitchell.com) with
  a documented RepairCenter Transactional API and a defined "7 steps to
  create an app" onboarding flow. This is the more directly self-serve path
  — register there, get a real client ID, drop it into `InsurerProvider.mitchell`.
- **CCC**: integration goes through their Secure Share marketplace, which
  requires active CIECA membership before you're issued real credentials.
  There's no public self-serve signup the way Mitchell has one.

**Also not built yet**: the actual estimate push/pull logic — pulling a claim
into DentDOG, or pushing a completed estimate back out in whatever format
each provider expects (likely CIECA BMS/XML today, possibly their emerging
JSON API standards down the road). The OAuth layer is the front door; what
happens after you're authenticated is provider-specific work that depends on
documentation you'll only get once you're actually registered as a partner.

## ⚠️ Status of this build — read before assuming anything works

**None of this has been compiled.** There is no Swift toolchain available in the
environment this was built in — everything below was written by hand-porting the
web build's logic and sanity-checked for brace/paren balance only, not run through
`swiftc` or Xcode. Treat this as a strong first draft, not verified-working code.
The very first thing to do with this zip is get it building in Xcode (see below)
and fix whatever the compiler flags — there will likely be *something*.

Per-file risk, roughly ordered from "probably fine" to "genuinely uncertain":

1. **VehicleMapView.swift** — standard `GeometryReader` + `.position()` pattern,
   lowest risk of the four new pieces.
2. **Models.swift additions** (`VehicleDeckState`) — trivial wrapper, low risk.
3. **PanelStackView.swift rewrite** — the tilt-then-swipe gesture math is a direct
   port of the web version's logic, but SwiftUI's gesture recognizer behavior
   doesn't always match a browser's pointer events 1:1. The axis-lock and the
   mid-drag `switchVehicle()` call (triggered from inside `.onChanged`, not
   `.onEnded`) are the parts most likely to need on-device tuning — for example,
   the deck-switch threshold (55pt) and tilt-ratio threshold (0.35) were carried
   over as numbers, not re-tuned for touch vs. mouse.
4. **EstimateExporter.swift** — real `UIGraphicsPDFRenderer` code, but the column
   x-positions and line-height numbers are estimated by eye, not measured against
   an actual render the way the Python/reportlab version was (that one was
   rendered to PNG and pixel-checked before shipping — this one can't be, in this
   environment). Expect to nudge spacing once you can see real output.
5. **CameraViewfinder.swift** — real `AVCaptureSession` code following Apple's
   standard patterns (session queue, delegate-based photo capture, `UIViewRepresentable`
   preview layer), but camera code is the single hardest thing to get right without
   a physical device to test on, and this environment has neither a device nor a
   simulator with camera passthrough. This is the file most likely to need real
   fixes once you run it.

## Capture flow

Double-tap opens `CameraViewfinder` — a real in-app live camera preview, not the
system picker. `CameraCapture.swift` (the old `UIImagePickerController` approach)
is still in the project but unused; swap it back in `PanelStackView.swift`'s
`.sheet(isPresented: $showCamera)` if the AVFoundation version gives you trouble
and you want the simpler, more battle-tested native picker while you debug.

## Multi-vehicle switching

Tilt the deck (swipe up/down on the front card), then — while still tilted —
keep swiping horizontally. Past the threshold, the active vehicle switches. This
matches the current web build's combined gesture. Not yet ported: the dimmed
"peek at the deck behind before switching" visual — right now the switch is
instant with no preview, since that visual effect needs its own layered
rendering pass this port didn't get to.

## Panel map & PDF export

Two buttons overlay the deck — grid icon (top-left) opens `VehicleMapView`,
share icon (top-right) generates a PDF via `EstimateExporter` and hands it to
iOS's share sheet (Save to Files, AirDrop, Mail, etc.). Both are wired to the
currently active vehicle's deck.

## LiDAR dent measurement (added — `LidarDepthManager.swift` + 4 others)

A "Measure with LiDAR" button sits under the size chips on each panel card.
Opens a full-screen live camera view (`LidarMeasureView`) that tracks a
detected dent region and reports real-world size, then auto-fills the
closest `DentSize` bucket by matching against actual US coin diameters
(dime/nickel/quarter/half-dollar — verified against US Mint specs).

**Two measurement paths, chosen automatically:**
- **LiDAR** (iPhone 12 Pro and later Pro models) — `ARKit`'s scene depth
  gives real distance-to-panel, which combined with camera focal length
  converts a pixel measurement to millimeters via standard pinhole-camera
  math.
- **Reference marker fallback** (any device, no LiDAR needed) — detects
  either a 1" circular magnet (via `Vision` contour detection + a
  circularity score, tuned for curved steel panels) or a standard ID-1
  card (85.6mm, credit-card-sized) via `VNDetectRectanglesRequest`, and
  scales pixel measurements against that known real-world size instead.
  This is what runs automatically on any non-LiDAR iPhone — the feature
  isn't Pro-model-only, just more accurate on Pro models.

**The one real gap, stated plainly**: `LiveTrackingController` finds the
dent *region* to measure via `PlaceholderDentRegionDetector` — a fixed box
in the middle of frame, not real dent detection. It's wired behind a
`DentRegionDetecting` protocol specifically so the real algorithm can be
swapped in later without touching anything else in this file. That real
algorithm already exists — `detectDentsClassicalCV()` in `DentDOG.html` —
but it's JavaScript/Canvas-based and still needs a native Swift port
(Core Image or Accelerate/vImage would be the natural translation) before
this stops being a placeholder. Until then: point the box at the dent
yourself, the size measurement itself is real, just the auto-detection of
*where* to measure isn't yet.

## Home screen widget (`DentDOGWidget/`)

A WidgetKit extension — small and medium sizes, one working button today:
**Start New Estimate**, which deep-links into the app (`dentdog://newEstimate`)
and resets both decks via `NotificationCenter` (`PanelStackView`'s
`.onReceive` + `VehicleDeckState.reset()`, wired in `DentDOGApp.swift`'s new
`onOpenURL`).

**What's real vs. scaffold, plainly:**
- The deep-link button is fully wired and doesn't depend on anything else —
  should work as soon as the extension target builds.
- `StartNewEstimateIntent.swift` (App Intents) is a working example but isn't
  what drives the current button — a plain `Link()` does that more simply.
  Kept as the pattern to extend the moment a widget button needs to actually
  *do* something rather than navigate.
- `DentDOGEntry` already has `lastEstimateTotal`/`panelsToday` fields, but
  they're always `nil` right now — showing real numbers needs two things
  this project doesn't have yet: (1) persistence in the main app at all
  (nothing saves an estimate anywhere — same known gap as always, the web
  build solved this with IndexedDB, Swift hasn't), and (2) an **App Group**
  so the widget process can read that data, since a widget extension can't
  see the main app's local storage otherwise. Full detail in the header
  comment of `DentDOGWidgetBundle.swift`.

**Manual Xcode setup** (XcodeGen's `project.yml` now defines this target, but
if you're adding it by hand instead):
1. File → New → Target → Widget Extension, name it `DentDOGWidget`, uncheck
   "Include Configuration Intent" (this project's `StaticConfiguration`
   doesn't use one).
2. Delete the placeholder files Xcode generates: replace with the four
   `.swift` files in `DentDOGWidget/` here.
3. The widget extension's deployment target needs to be **iOS 17**, even
   though the main app targets iOS 16 — `.containerBackground(for: .widget)`
   requires it. Xcode sets this automatically for new Widget Extension
   targets; if adjusting manually, don't drag the main app's target down to
   match, they're allowed to differ.
4. Add the dog badge image to the widget extension's **own** asset catalog —
   widget extensions are a separate bundle and can't read the main app
   target's `Assets.xcassets`. Simplest fix: select the image asset in
   Xcode's asset catalog, and in the File Inspector, check the box for the
   widget extension target too (shares the same file, no duplication needed).
   The widget falls back to a plain SF Symbol paw icon if this step is
   skipped — won't crash, just won't show the real logo.
5. Build the `DentDOGWidgetExtension` scheme once standalone to catch
   extension-specific errors before testing it embedded in the main app.

## Before it builds

**Option A — Xcode, when you have a Mac:**
1. Create a new Xcode iOS App project named **DentDOG** (SwiftUI, no Core Data), then drop
   all the `.swift` files into it, replacing the default `ContentView.swift`/`App.swift`.
   Use `DentDOG/Info.plist` as-is or merge its camera key into Xcode's generated one.
2. Minimum deployment target: iOS 16.

**Option B — Codemagic, no Mac needed (see below).**

## No-Mac build path — step by step

This project includes `project.yml` (XcodeGen) and `codemagic.yaml`, which together
generate the `.xcodeproj` and build it entirely in the cloud — you never touch Xcode.

1. **Push this folder to a GitHub repo.**
   ```
   git init
   git add .
   git commit -m "DentDOG"
   git remote add origin <your-repo-url>
   git push -u origin main
   ```
2. **Sign up at codemagic.io** (free tier covers this) and connect that repo.
3. Codemagic detects `codemagic.yaml` and shows the **dentdog-simulator-preview**
   workflow. Hit **Start new build**.
4. The pipeline installs XcodeGen, generates the Xcode project, builds for the iOS
   Simulator, boots it, installs the app, launches it, and takes a screenshot.
   Note: the iOS **Simulator has no real camera** — `CameraViewfinder`'s
   `AVCaptureDevice.default(...)` lookup will return `nil` on the simulator, so
   the capture button won't produce a photo there. You'll need a **real device**
   build (which needs paid signing, see below) to actually test the camera.
5. Open the **Artifacts** tab — `dentdog_preview.png` is a real screenshot of
   DentDOG actually running.

Installing on your own iPhone is a separate later step requiring a paid Apple
Developer account ($99/yr) and signing certs set up in the Codemagic dashboard —
this is also the only way to actually test `CameraViewfinder` for real.

## Known gaps still remaining

- No persistence for panel field data (dent bracket, size, photo, etc. reset
  on relaunch) — only deck order persists (`UserDefaults`, key `haildeck.deckOrder`).
- The "peek at the deck behind" dimmed visual during tilt (see above).
- PDF export layout is unmeasured (see risk list above).
- DOG (Difference-of-Gaussians dent detection + dentsity scoring) exists only
  on the web build right now — Import just got ported here, DOG hasn't yet.
- LiDAR dent-region detection is a placeholder (see the LiDAR section above)
  — the size *measurement* is real, finding *where* to measure isn't yet.
- LiDAR/AR can't be tested in the Simulator at all — no depth sensor, and
  ARKit world tracking doesn't run properly there either. Same real-device
  requirement as `CameraViewfinder`, just stricter: the camera fallback at
  least partially works in Simulator testing (returns nil gracefully),
  ARKit sessions generally won't start.
