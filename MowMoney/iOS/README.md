# Mow Money for iOS

This is a native iOS version of the Mow Money web game (`../index.html`), built with SpriteKit and SwiftUI. It uses only Apple frameworks: no packages, no asset files and no Info.plist changes. Textures are drawn in code and sounds are synthesized.

## Put it in Xcode

1. In Xcode, choose **File → New → Project → iOS → App**.
   - Product Name: `MowMoney`
   - Interface: **SwiftUI**
   - Language: **Swift**
2. In the new project, delete the template's `ContentView.swift` and `MowMoneyApp.swift` (choose **Move to Trash**).
3. Drag the `MowMoney/iOS/MowMoney` folder from this repo into the Xcode project navigator. Check **Copy items if needed** and your app target.
4. Under **Target → General**, set **Minimum Deployments** to iOS 16.0 or later.
5. Pick an iPhone simulator and press **⌘R**.

Portrait orientation is locked in code (`AppDelegate` in `MowMoneyApp.swift`), so you don't need to change orientation settings.

If Xcode reports a compile error, paste it into Claude (in Xcode or here). This code was written without access to a Mac, so the first build is its first real compile.

## Files

| File | What it does |
|---|---|
| `MowMoneyApp.swift` | App entry point, portrait lock |
| `Screens.swift` | SwiftUI screens (Title, HUD, Pause, Job done, Garage, banner) and the chunky theme |
| `GameSession.swift` | Shared state between the game scene and the screens: mode, HUD values, results and all button actions |
| `GameScene.swift` | The SpriteKit game: driving, collisions, mowing, combos, dandelions, power-ups, finishing a job, stripe scoring, camera, and the title-screen autopilot |
| `Nodes.swift` | Drawing for the mowers, house, car, pool, trees, gnomes, rocks, power-ups, floating text, clippings and confetti |
| `Joystick.swift` | Floating touch joystick and minimap |
| `Lawn.swift` | Yard generator (same seed and same layout as the web version) |
| `LawnTiles.swift` | Tile textures for grass, stripes, flowers, paths and mulch |
| `SeededRandom.swift` | Seeded random numbers that match the web version bit for bit |
| `Catalog.swift` | Mowers, upgrades, power-ups and formatting helpers |
| `SaveStore.swift` | Saves progress in `UserDefaults` |
| `SoundEngine.swift` | Synthesized engine hum, grass-cutting noise and sound effects |
| `Haptics.swift` | Vibration feedback |

## Tuning

Every number matches the web version, so both play the same:

- **Pay per sq ft:** `0.8 × (1 + 0.08 × (job − 1)) × curb appeal × combo`
- **Job fee:** `200 + 60 × job`
- **Tip:** `stars × (80 + 30 × job)`
- **Flower damage:** $40 for each flower mowed
- **Combo:** goes up one step for every `50 × deck` sq ft cut without a break, up to x5
- **Stars** (one each):
  - beat par time
  - flower beds intact (up to 5% lost)
  - stripes at least 70% straight
