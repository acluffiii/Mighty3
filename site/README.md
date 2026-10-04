# Sunovabit website

Plain static HTML and CSS: no build step, no framework, no cost. Open any `.html` file in a browser to preview it.

```
index.html              Company home (apps, custom solutions, our roots, contact)
dentdog/                DentDOG PDR: product page, support.html, privacy.html
mowmoney/               Mow Money: product page, support.html, privacy.html
privacy.html            Website privacy policy
404.html                "Well, that's a sunovabit." page
assets/css/site.css     All styles (light and dark mode)
assets/img/             Logos and app icons
```

## URLs for App Store Connect

| App | Support URL | Privacy Policy URL | Marketing URL (optional) |
|---|---|---|---|
| DentDOG PDR | `https://<your-site>/dentdog/support.html` | `https://<your-site>/dentdog/privacy.html` | `https://<your-site>/dentdog/` |
| Mow Money | `https://<your-site>/mowmoney/support.html` | `https://<your-site>/mowmoney/privacy.html` | `https://<your-site>/mowmoney/` |

`<your-site>` is `sunovabit.github.io` until you buy the domain, then `sunovabit.com`.

## Hosting it free on GitHub Pages (about 15 minutes)

1. **Create a free GitHub organization** named `sunovabit` (github.com → your avatar → *Your organizations* → *New organization* → Free plan). That makes the free URL `https://sunovabit.github.io` instead of one with your personal username in it.
2. **Create a public repository** in that org named exactly `sunovabit.github.io`.
3. **Upload the contents of this `site/` folder**: the files themselves, not the folder. Use *Add file → Upload files*, or git:
   ```bash
   git clone https://github.com/sunovabit/sunovabit.github.io.git
   cp -R site/* sunovabit.github.io/
   cd sunovabit.github.io && git add . && git commit -m "Launch site" && git push
   ```
4. In the repo, go to **Settings → Pages**. Under *Build and deployment*, choose **Deploy from a branch**, pick `main` and `/ (root)`, then click **Save**.
5. Wait 1–2 minutes, then open `https://sunovabit.github.io`. That URL works in App Store Connect right away.

## Adding your custom domain later (sunovabit.com)

1. Buy `sunovabit.com` at **Cloudflare Registrar** (at-cost pricing, about $10–11 a year) or Porkbun.
2. In your DNS settings, add these records:
   - `A` records for `@` → `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - `CNAME` record for `www` → `sunovabit.github.io`
   - On Cloudflare, set these records to **DNS only** (grey cloud) until GitHub has issued your certificate.
3. Rename `CNAME.example` to `CNAME` (it contains `sunovabit.com`) and push it.
4. In **Settings → Pages**, enter `sunovabit.com` as the custom domain, wait for the DNS check, then tick **Enforce HTTPS**.
5. Update the URLs in App Store Connect, and search and replace `https://sunovabit.github.io/assets/img/og-image.png` with `https://sunovabit.com/assets/img/og-image.png` (this is the image link previews use). Optional: set up free Cloudflare **Email Routing** so `support@sunovabit.com` forwards to your iCloud, then replace the email address in the pages.

## Editing

Every page uses the same header and footer, so a change to the menu has to be made in each `.html` file. Search and replace works well for that. The support email appears as `acluffiii@icloud.com`; search and replace it when you switch to `support@sunovabit.com`.

> The privacy policies are written plainly and match how the apps work today (no accounts, no ads, no tracking). Update them **before** you add ads, analytics, sign-in, or online features. If you want legal certainty, have a lawyer review them.
