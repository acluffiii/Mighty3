// Rebuilds every Sunovabit PNG from its SVG source.
//   node Brand-Assets/sunovabit/render-icons.js
// Needs Node, Playwright (Chromium) and ImageMagick's `convert` (for downscaling and stripping alpha).
const path = require('path');
const fs = require('fs');
const { execFileSync } = require('child_process');
let chromium;
try { ({ chromium } = require('playwright')); }
catch { ({ chromium } = require('/opt/node22/lib/node_modules/playwright')); }

const HERE = __dirname;
const SITE_IMG = path.join(HERE, '..', '..', 'site', 'assets', 'img');
const ICON = path.join(HERE, 'app-icon');

// [svg source, png output, width, height]
const renders = [
  [path.join(ICON, 'sunovabit-app-icon.svg'), path.join(ICON, 'AppIcon-1024.png'), 1024, 1024],
  [path.join(ICON, 'sunovabit-app-icon-small.svg'), path.join(ICON, 'small-1024.tmp.png'), 1024, 1024],
  [path.join(HERE, 'social', 'og-image.svg'), path.join(SITE_IMG, 'og-image.png'), 1200, 630],
];

// Sizes downscaled from the detailed master, and favicons from the simplified version
const fromMaster = [180, 167, 152, 120, 87, 80, 60, 58, 40];
const fromSmall = [64, 48, 32, 16];

const convert = (...args) => execFileSync('convert', args);

(async () => {
  const browser = await chromium.launch();
  for (const [src, out, w, h] of renders) {
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    await page.goto('file://' + src);
    await page.screenshot({ path: out, omitBackground: false });
    await page.close();
    convert(out, '-background', '#13213a', '-alpha', 'remove', '-alpha', 'off', out); // Apple rejects icons with alpha
    console.log('rendered', path.relative(HERE, out));
  }
  await browser.close();

  const sizes = path.join(ICON, 'sizes');
  fs.mkdirSync(sizes, { recursive: true });
  const master = path.join(ICON, 'AppIcon-1024.png');
  const small = path.join(ICON, 'small-1024.tmp.png');
  for (const s of fromMaster) convert(master, '-filter', 'Lanczos', '-resize', `${s}x${s}`, '-alpha', 'off', path.join(sizes, `icon-${s}.png`));
  for (const s of fromSmall) convert(small, '-filter', 'Lanczos', '-resize', `${s}x${s}`, '-alpha', 'off', path.join(sizes, `icon-${s}.png`));

  // Xcode asset catalog (single-size format, Xcode 14+)
  const set = path.join(ICON, 'AppIcon.appiconset');
  fs.mkdirSync(set, { recursive: true });
  fs.copyFileSync(master, path.join(set, 'AppIcon-1024.png'));
  fs.writeFileSync(path.join(set, 'Contents.json'), JSON.stringify({
    images: [{ filename: 'AppIcon-1024.png', idiom: 'universal', platform: 'ios', size: '1024x1024' }],
    info: { author: 'xcode', version: 1 },
  }, null, 2) + '\n');

  // Website icons
  fs.copyFileSync(path.join(sizes, 'icon-180.png'), path.join(SITE_IMG, 'apple-touch-icon.png'));
  fs.copyFileSync(path.join(sizes, 'icon-32.png'), path.join(SITE_IMG, 'favicon-32.png'));
  fs.copyFileSync(path.join(sizes, 'icon-16.png'), path.join(SITE_IMG, 'favicon-16.png'));
  fs.unlinkSync(small);
  console.log('done');
})();
