# Thumbit website + DentDOG launch kit

A static website for **Thumbit** (the company) and **DentDOG** (its first app).
It's plain HTML and CSS with no build step, no web fonts, and no trackers. Upload the
`Website/` folder as-is to any static host.

```
Website/
├── index.html              Thumbit company home
├── dentdog/
│   ├── index.html          DentDOG product page   → App Store "Marketing URL"
│   ├── privacy.html        Privacy Policy         → App Store "Privacy Policy URL" (required)
│   ├── support.html        Support + FAQ          → App Store "Support URL" (required)
│   └── terms.html          Terms of Use (sits on top of Apple's standard EULA)
├── 404.html
└── assets/
    ├── site.css
    ├── brand/              Thumbit logo files (SVG masters + PNG exports)
    └── dentdog/            DentDOG icon for the site
```

## Before it goes live: 3 find-and-replace items

| Placeholder | Where | Replace with |
|---|---|---|
| `support@thumbit.com` | every page | The real support inbox, once you own the domain. |
| `id="app-store-link"` button | `dentdog/index.html` | Apple's official **Download on the App Store** badge (from tools.applemarketingtools.com), linked to your App Store URL. Do this on launch day. |
| "Coming soon" tag | `index.html` | Remove it at launch. |

The legal pages are dated **September 24, 2026**. If you change what the app does
with data, update both the date and the text.

> The privacy policy and terms were written to match what the code does
> today: no accounts, no analytics, no servers, and all data kept on the device.
> They're a solid starting point, not legal advice. Have a lawyer review them,
> especially the Terms, if you add accounts, cloud sync, payments, or
> subscriptions. If you add any SDK (analytics, crash reporting, ads), update
> the policy and the App Store privacy label **before** that build ships.

## Hosting (pick one; all are free for a site like this)

- **Cloudflare Pages** or **Netlify**: drag and drop the `Website/` folder,
  then connect your domain. This is the easiest option.
- **GitHub Pages**: needs a public repo, or a paid plan for a private repo.
  Point it at the `Website/` folder.

Use HTTPS (all three do it automatically). Apple rejects Privacy Policy URLs
that don't load.

## Brand files

| File | Use |
|---|---|
| `thumbit-logo.svg` / `-light.svg` | Horizontal logo for light / dark backgrounds |
| `thumbit-logo.png` / `-light.png` | Same, 2080 px wide, transparent background |
| `thumbit-mark.svg` / `-light.svg` / `.png` | Thumbprint mark on its own |
| `thumbit-wordmark.svg` / `-light.svg` | THUMBIT lettering only |
| `thumbit-icon.svg` / `-1024.png` / `-180.png` | Square avatar for social media, favicon, and the App Store Connect developer profile |

The colors are Ink `#15181d`, Cream `#f3ead8`, and Signal Red `#d0271d`. They're
taken from the DentDOG icon so the company and the app look like one family.
The letters are drawn as shapes, not typed in a font, so the SVGs look the same
everywhere.

**The idea behind the mark:** a thumbprint whose ridges are also contour rings.
That's how DentDOG "sees" a dent (a Difference-of-Gaussians ring pattern). The
red dot is the dent at the center, and it doubles as the dot on the "i."

---

# App Store launch checklist

## 1. Company setup (start now; these steps take the longest)
- [ ] **Form the business** (for example Thumbit LLC) if you want "Thumbit" shown as
      the seller on the App Store. An individual developer account shows your
      personal name instead.
- [ ] **Get a D-U-N-S number** (free, from Dun & Bradstreet). Apple requires one for
      an Organization account. **It can take 1–2 weeks**, so request it first.
- [ ] **Enroll in the Apple Developer Program as an Organization** ($99/yr).
- [ ] Register the domain, then set up the support email address.
- [ ] Do a trademark search for "THUMBIT" and "DentDOG" (USPTO search) before
      you print anything.

## 2. App Store Connect answers for DentDOG

**URLs**
- Privacy Policy URL: `https://<your-domain>/dentdog/privacy.html`
- Support URL: `https://<your-domain>/dentdog/support.html`
- Marketing URL: `https://<your-domain>/dentdog/`

**App Privacy ("nutrition label")**: choose **"No, we do not collect data from
this app."** That's accurate because the code has no analytics or network
calls except the optional Mitchell/CCC OAuth, and that goes straight to those
providers. It shows as **"Data Not Collected"** on the listing.
If Mitchell/CCC connections actually ship, check again what data flows to
them.

**Age rating questionnaire**: answer **None / No** to every content question
(violence, sexual content, profanity, gambling, horror, drugs, and so on) and
**No** to unrestricted web access, user-generated content, and messaging.
The result is **4+**, which matches the website.

**Other fields**
- Category: **Business** (secondary: **Utilities** or **Productivity**)
- Copyright: `2026 Thumbit`
- Price: your call. For paid or in-app purchases, finish the Paid Apps agreement
  and tax/banking forms in App Store Connect early.
- Export compliance: the app only uses Apple's built-in HTTPS and CryptoKit
  (hashing for PKCE). Answer "uses exempt encryption". To stop being asked every
  build, add `ITSAppUsesNonExemptEncryption = NO` to `Info.plist`.
- Sign-in required for review: **No** (DentDOG has no accounts).

## 3. Code issues that could get the build rejected
These came up while checking the app for this policy. Fix them before you submit:

- [ ] **Mitchell / CCC "Connect" screen uses placeholder client IDs.**
      `OAuthClient.swift` still has `REPLACE_WITH_…_CLIENT_ID`, and
      `InsurerConnectView` can be opened from the deck. App Review rejects
      features that don't work (Guideline 2.1). Hide that button until you have
      real partner credentials.
- [ ] **`UIRequiredDeviceCapabilities` lists `armv7`.** That's a 32-bit
      requirement from before iOS 11. Change it to `arm64` (or remove the key). Otherwise
      App Store Connect may reject the upload or limit which devices can
      install the app.
- [ ] **Estimates aren't saved yet** (see `Swift/README.md`, "Known gaps"). If
      the app closes, the user loses their work. That's a serious problem for a
      paid tool and a common reason for 1-star reviews.
- [ ] Camera-permission text in `Info.plist` is fine. Consider changing it to
      "DentDOG uses the camera to photograph vehicle panels and measure dent size."
      so it also covers LiDAR measurement.
- [ ] Bundle ID is still `com.cluffwork.haildeck`. Before creating the App Store
      record, decide whether to switch to something like `com.thumbit.dentdog`.
      After the first upload it can't be changed.
- [ ] Test on a real device through TestFlight, especially the camera, LiDAR, and
      PDF export, which can't be tested in the Simulator.

## 4. Store listing assets
- [ ] App icon 1024×1024 (already have: `Brand-Assets/dentdog_app_icon.png`)
- [ ] iPhone screenshots: 6.9" (1320×2868) is required; Apple scales it down for
      smaller devices. 3–5 shots: the deck, a panel card with a price, LiDAR
      measure, the PDF, and the vehicle map.
- [ ] Subtitle (30 characters), for example "Hail damage estimates"
- [ ] Keywords (100 characters), for example `PDR,hail,dent,estimate,paintless,auto body,LiDAR,panel,repair,insurance`
- [ ] Description (you can adapt the copy on `dentdog/index.html`)

## 5. Suggested timeline for a ~1-month launch
| Week | Do |
|---|---|
| 1 | D-U-N-S + LLC + Apple enrollment; buy domain; deploy this site |
| 2 | Fix the code issues in section 3; TestFlight on real iPhones |
| 3 | Screenshots, listing copy, App Store Connect forms; submit for review |
| 4 | Review usually takes 1–3 days, but leave room for one rejection and resubmit; then release |
