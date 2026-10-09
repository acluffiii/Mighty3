# Sunovabit website

Plain static HTML and CSS: no build step, no framework, no database. Open any `.html` file in a browser to preview it. It runs on any web host. The two easiest are **Bluehost** (option A, paid, includes a domain and email) and **GitHub Pages** (option B, free).

```
index.html              Company home (apps, custom solutions, our roots, contact)
dentdog/                DentDOG PDR: product page, support.html, privacy.html
mowmoney/               Mow Money: product page, support.html, privacy.html
privacy.html            Website privacy policy
404.html                "Well, that's a sunovabit." page
assets/css/site.css     All styles (light and dark mode)
assets/img/             Logos and app icons
.htaccess               Bluehost/Apache settings: https redirect, 404 page, caching (hidden file)
build-zip.sh            Rebuilds sunovabit-site.zip after you edit anything
sunovabit-site.zip      Ready-to-upload bundle for Bluehost
```

## URLs for App Store Connect

| App | Support URL | Privacy Policy URL | Marketing URL (optional) |
|---|---|---|---|
| DentDOG PDR | `https://<your-site>/dentdog/support.html` | `https://<your-site>/dentdog/privacy.html` | `https://<your-site>/dentdog/` |
| Mow Money | `https://<your-site>/mowmoney/support.html` | `https://<your-site>/mowmoney/privacy.html` | `https://<your-site>/mowmoney/` |

`<your-site>` is `sunovabit.com` on Bluehost. With GitHub Pages, it's `sunovabit.github.io` until you connect the domain.

## Option A: Hosting on Bluehost (about 20 minutes)

Bluehost's intro price for the Basic plan is a few dollars a month, paid 12–36 months up front, and it renews at a higher price. It includes a **free domain for the first year**, free SSL (the https padlock), and **email inboxes** like `support@sunovabit.com`.

1. **Sign up** at bluehost.com and pick the cheapest shared hosting plan (Basic). When it asks for a domain, choose **sunovabit.com**. At checkout, **untick the extras** (SiteLock, Codeguard, "Pro" SEO tools); the site doesn't need them.
2. **Skip WordPress.** During onboarding, Bluehost offers to install WordPress or a site builder. Choose *Skip* or *I don't need help*. WordPress would replace this site with something you'd have to keep updating.
3. **Upload the site:**
   1. Open your Bluehost dashboard → **Hosting** (or **Advanced**) → **cPanel** → **File Manager**.
   2. Open the **`public_html`** folder. Delete any placeholder files in it (`index.html`, `default.html`, `coming-soon` files). Don't delete `cgi-bin` or `.well-known` if they're there.
   3. Click **Upload** and choose `sunovabit-site.zip` from this folder.
   4. Back in File Manager, right-click the zip → **Extract** → extract into `/public_html`. Then delete the zip.
   5. Check: `public_html` should now hold `index.html`, `404.html`, `privacy.html`, and the folders `assets`, `dentdog` and `mowmoney`. The `.htaccess` file is hidden; to see it, click **Settings** (top right) → tick **Show Hidden Files**.
4. **Turn on SSL:** dashboard → **Security** (or **Websites → Security**) → turn on the free **SSL certificate**. It can take a few minutes to a few hours to activate. Once it's on, `.htaccess` sends every visitor to `https://sunovabit.com`.
5. **Set up email:** dashboard → **Email** → create `support@sunovabit.com`. You can forward it to your iCloud so everything lands in one inbox. Then ask Claude, or use search and replace, to swap `acluffiii@icloud.com` for `support@sunovabit.com` in every page, and re-upload.
6. **Test:** open `https://sunovabit.com`, `https://sunovabit.com/dentdog/`, and `https://sunovabit.com/nope` (you should see the "Well, that's a sunovabit." page). Then paste the URLs above into App Store Connect.

**Updating the site later:** edit the files, run `bash site/build-zip.sh`, and upload and extract the new zip over the old files. Or upload just the files you changed through File Manager.

> **New domain, slow start:** a brand-new domain can take up to 24–48 hours to work everywhere. If the site doesn't load right away, wait and try again before changing anything.

## Option B: Hosting it free on GitHub Pages (about 15 minutes)

1. **Create a free GitHub organization** named `sunovabit` (github.com → your avatar → *Your organizations* → *New organization* → Free plan). That makes the free URL `https://sunovabit.github.io` instead of one with your personal username in it.
2. **Create a public repository** in that org named exactly `sunovabit.github.io`.
3. **Upload the contents of this `site/` folder**: the files themselves, not the folder. (`.htaccess` and the zip are only for Bluehost; they're harmless here.) Use *Add file → Upload files*, or git:
   ```bash
   git clone https://github.com/sunovabit/sunovabit.github.io.git
   cp -R site/* sunovabit.github.io/
   cd sunovabit.github.io && git add . && git commit -m "Launch site" && git push
   ```
4. In the repo, go to **Settings → Pages**. Under *Build and deployment*, choose **Deploy from a branch**, pick `main` and `/ (root)`, then click **Save**.
5. Wait 1–2 minutes, then open `https://sunovabit.github.io`. That URL works in App Store Connect right away.

### Connecting a custom domain to GitHub Pages

1. Buy `sunovabit.com` at **Cloudflare Registrar** (at-cost pricing, about $10–11 a year) or Porkbun.
2. In your domain's DNS settings, add these records:
   - `A` records for `@` → `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - `CNAME` record for `www` → `sunovabit.github.io`
   - On Cloudflare, set these records to **DNS only** (grey cloud) until GitHub has issued your certificate.
3. Rename `CNAME.example` to `CNAME` (it contains `sunovabit.com`) and push it.
4. In **Settings → Pages**, enter `sunovabit.com` as the custom domain, wait for the DNS check, then tick **Enforce HTTPS**.
5. Update the URLs in App Store Connect. Optional: set up free Cloudflare **Email Routing** so `support@sunovabit.com` forwards to your iCloud, then replace the email address in the pages.

## Editing

Every page uses the same header and footer, so a change to the menu has to be made in each `.html` file. Search and replace works well for that. Link previews (when someone shares the site in a text or on social media) use `https://sunovabit.com/assets/img/og-image.png`; if the site lives at a different address, search and replace that address too. The support email appears as `acluffiii@icloud.com`; search and replace it when you switch to `support@sunovabit.com`.

> The privacy policies are written plainly and match how the apps work today (no accounts, no ads, no tracking). Update them **before** you add ads, analytics, sign-in, or online features. If you want legal certainty, have a lawyer review them.
