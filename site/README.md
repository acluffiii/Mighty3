# Sunovabit website

Plain static HTML and CSS: no build step, no framework, no database. Open any `.html` file in a browser to preview it. It runs on any web host. The two easiest are **Hostinger** (option A, paid, includes a domain and email) and **GitHub Pages** (option B, free).

```
index.html              Company home (apps, custom solutions, our roots, contact)
dentdog/                DentDOG PDR: product page, support.html, privacy.html
mowmoney/               Mow Money: product page, support.html, privacy.html
contact/                Contact form (index.html), thank-you page, and send.php, which emails messages to you
preloader/              Preloader: product page with screenshot gallery, support/, privacy/, terms/ (folder-style URLs). Old /preload/ links redirect here.
privacy.html            Website privacy policy
404.html                "Well, that's a sunovabit." page
assets/css/site.css     All styles (light and dark mode)
assets/img/             Logos and app icons
.htaccess               Hostinger/Apache settings: https redirect, 404 page, caching (hidden file)
build-zip.sh            Rebuilds sunovabit-site.zip after you edit anything
sunovabit-site.zip      Ready-to-upload bundle for Hostinger
```

## URLs for App Store Connect

| App | Support URL | Privacy Policy URL | Marketing URL (optional) |
|---|---|---|---|
| DentDOG PDR | `https://<your-site>/dentdog/support.html` | `https://<your-site>/dentdog/privacy.html` | `https://<your-site>/dentdog/` |
| Mow Money | `https://<your-site>/mowmoney/support.html` | `https://<your-site>/mowmoney/privacy.html` | `https://<your-site>/mowmoney/` |
| Preloader | `https://<your-site>/preloader/support/` | `https://<your-site>/preloader/privacy/` | `https://<your-site>/preloader/` |

**DentDOG Terms of Use (EULA):** `https://<your-site>/dentdog/terms.html`. Because DentDOG sells an auto-renewing subscription, Apple requires a Terms of Use link in the app's Description (or in App Store Connect's EULA field), and the app's subscription screen must link to both this page and the privacy policy.

**Use the same domain everywhere.** The site is set up for `sunovabit.org`. App Review rejected the first DentDOG submission because the Support URL was `http://www.sunovabit.com`, which doesn't load. Every URL in App Store Connect must start with `https://sunovabit.org/`.

`<your-site>` is `sunovabit.org` on Hostinger. With GitHub Pages, it's `sunovabit.github.io` until you connect the domain.

## Option A: Hosting on Hostinger (current host)

Hostinger supports everything this site uses: plain HTML pages, the PHP contact form, and the `.htaccess` settings file (https and www redirects, the custom 404 page, and the old `/preload/` links forwarding to `/preloader/`).

1. **Upload:** in **hPanel**, go to **Websites**, click **Dashboard** for sunovabit.org, then open **File Manager** and the **`public_html`** folder. Delete Hostinger's placeholder page (`default.php` or `index.php`). Click **Upload**, choose **File**, and pick `sunovabit-site.zip`.
2. **Extract:** right-click the zip, choose **Extract**, and extract straight into `public_html` (not a subfolder). Delete the zip. `public_html` should now hold `index.html` and the folders `assets`, `contact`, `dentdog`, `mowmoney` and `preloader`. The `.htaccess` file is hidden by default.
3. **SSL:** under **Security → SSL**, the free certificate should show **Active**. Hostinger usually turns it on automatically within an hour.
4. **Domain:** if sunovabit.org was bought somewhere else, change its nameservers to the ones hPanel shows under **Domains**. It can take up to 24 hours to work everywhere.
5. **Contact form:** under **Emails**, create `no-reply@sunovabit.org` (the address the form sends from). Then send a test message from `https://sunovabit.org/contact/` and check your iCloud inbox, including **Junk**.
6. **Test the pages:** open `https://sunovabit.org`, `https://sunovabit.org/dentdog/`, and `https://sunovabit.org/nope` (you should see the "Well, that's a sunovabit." page). Then paste the URLs above into App Store Connect.

**Updating the site later:** run `bash site/build-zip.sh`, then upload and extract the new zip over the old files in `public_html`, saying yes to overwrite.

## Option B: Hosting it free on GitHub Pages (about 15 minutes)

1. **Create a free GitHub organization** named `sunovabit` (github.com → your avatar → *Your organizations* → *New organization* → Free plan). That makes the free URL `https://sunovabit.github.io` instead of one with your personal username in it.
2. **Create a public repository** in that org named exactly `sunovabit.github.io`.
3. **Upload the contents of this `site/` folder**: the files themselves, not the folder. (`.htaccess` and the zip are only for Hostinger; they're harmless here.) **Note:** GitHub Pages can't run PHP, so the contact form won't send messages there. It only works on Hostinger or another host with PHP. Use *Add file → Upload files*, or git:
   ```bash
   git clone https://github.com/sunovabit/sunovabit.github.io.git
   cp -R site/* sunovabit.github.io/
   cd sunovabit.github.io && git add . && git commit -m "Launch site" && git push
   ```
4. In the repo, go to **Settings → Pages**. Under *Build and deployment*, choose **Deploy from a branch**, pick `main` and `/ (root)`, then click **Save**.
5. Wait 1–2 minutes, then open `https://sunovabit.github.io`. That URL works in App Store Connect right away.

### Connecting a custom domain to GitHub Pages

1. Buy `sunovabit.org` at **Cloudflare Registrar** (at-cost pricing, about $10–11 a year) or Porkbun.
2. In your domain's DNS settings, add these records:
   - `A` records for `@` → `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - `CNAME` record for `www` → `sunovabit.github.io`
   - On Cloudflare, set these records to **DNS only** (grey cloud) until GitHub has issued your certificate.
3. Rename `CNAME.example` to `CNAME` (it contains `sunovabit.org`) and push it.
4. In **Settings → Pages**, enter `sunovabit.org` as the custom domain, wait for the DNS check, then tick **Enforce HTTPS**.
5. Update the URLs in App Store Connect.

## Contact form

The site never shows an email address. Every "contact" or "support" button goes to the form at `/contact/`. The form sends to `contact/send.php`, which emails the message to you. Your address appears **only** in `send.php`, which runs on the server and is never shown to visitors.

- **Where messages go:** `TO_EMAIL` near the top of `contact/send.php` (currently `acluffiii@icloud.com`). To change it, edit that one line and re-upload just `send.php`.
- **What you receive:** an email titled like `[Sunovabit] Preloader: Jane Doe` with the visitor's name, email, topic, device, and message. **Hit Reply** to answer them directly; your reply goes to their address.
- **Spam protection:** a hidden trap field that bots fill in (their messages are silently dropped), at most 5 messages per hour from one visitor, and messages with more than 3 links are refused. No CAPTCHA puzzles.
- **Sender address:** messages come from `no-reply@sunovabit.org` (`FROM_EMAIL`). It doesn't need to be a real mailbox, but it must use your own domain, or iCloud may reject the message. If messages ever stop arriving, create a real `no-reply@sunovabit.org` mailbox in Hostinger → Email; that usually fixes delivery.
- **Topics:** the dropdown choices are listed in both `contact/index.html` and `send.php`. Links like `/contact/?topic=preloader` pre-select a topic.

## Editing

Every page uses the same header and footer, so a change to the menu has to be made in each `.html` file. Search and replace works well for that. Link previews (when someone shares the site in a text or on social media) use `https://sunovabit.org/assets/img/og-image.png`; if the site lives at a different address, search and replace that address too.

> The privacy policies are written plainly and match how the apps work today (no accounts, no ads, no tracking). Update them **before** you add ads, analytics, sign-in, or online features. If you want legal certainty, have a lawyer review them.
