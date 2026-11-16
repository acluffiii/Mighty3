# ovayonder.sunovabit.org: shared-location page

`p/index.html` is the page a recipient sees when someone shares a pin from the OvaYonder app.

**URL:** `https://ovayonder.sunovabit.org/p/?lat=29.7604&lng=-95.3698&name=Downtown%20Houston`
(`/p?…` also works: the server redirects it to `/p/?…` and keeps the query string.)

- `lat` (−90…90) and `lng` (−180…180) are required decimal degrees; `name` is optional, URL-encoded, shown as plain text, max 80 characters.
- Invalid or missing coordinates show "This location link isn't valid" and no map.
- Map: OpenStreetMap embed with a marker (no API key). Buttons open Apple Maps or Google Maps; Apple first on iPhone/iPad/Mac, Google first on Android.
- Privacy: no cookies, storage, analytics or external scripts; referrers are off so the URL (with the coordinates) is never sent to other sites; a strict Content-Security-Policy only allows the page's own script.

## Upload to Hostinger

Upload `ovayonder-p-page.zip` to the **subdomain's own folder** (the document root for ovayonder.sunovabit.org, shown in hPanel under Domains → Subdomains), and extract it there. The zip only contains `p/index.html`, so it does not touch `/eta`, `/.well-known/apple-app-site-association`, or anything else in that folder.

If you edit the `<script>` in `p/index.html`, update the `sha256-…` hash in the Content-Security-Policy meta tag, or the browser will block the script.
