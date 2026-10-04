# Sunovabit app icon

**`AppIcon-1024.png`** is the master: 1024×1024, square, and opaque (no transparency), as Apple requires. Don't round the corners yourself; iOS does that.

## Using it
- **In an Xcode app:** delete the app's existing `AppIcon.appiconset` in `Assets.xcassets` and drag in the `AppIcon.appiconset/` folder from here. It uses the single-size format (Xcode 14 and later), and Xcode generates every smaller size.
- **In App Store Connect:** Xcode uploads the icon inside the build. You don't have to upload it separately.
- **On the website:** `site/assets/img/apple-touch-icon.png` and `favicon-*.png` were made from this icon.
- `sizes/` holds ready-made PNGs (16–180 px) for anything else: social profiles, email signatures, invoices. The 16–64 px files use the simplified version (`sunovabit-app-icon-small.svg`, no circuit traces) so they stay crisp in a browser tab.

## Editing
Edit the SVGs, then rebuild every PNG:
```bash
node Brand-Assets/sunovabit/render-icons.js
```
(Needs Node, Playwright, and ImageMagick.) Open `preview.html` to see the icon on light and dark Home Screens.

> This is the **Sunovabit company icon**, for the company's own listings and accounts. DentDOG keeps its own dog icon. Mow Money will need its own game icon. A small Juneteenth Nova badge in a corner of each app's icon is a nice way to tie them back to Sunovabit.
