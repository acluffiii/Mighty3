// Generates the Preload game home screen and app icon as SVG + PNG.
// Style: flat editorial illustration — no outlines, shading by tone, soft blue
// backdrop with pale blobs, and a film-grain overlay.
// Usage: NODE_PATH=$(npm root -g) node generate.js   (needs global `playwright`)
const fs = require('fs');
const path = require('path');

const OUT = path.resolve(__dirname, '..');
const FONT = fs.readFileSync(path.join(__dirname, 'Lexend-Bold.ttf')).toString('base64');

const C = {
  bg: '#6aaedc', bgDeep: '#5a9fd0', blob: '#a8d1ef', blobSoft: '#8cc2e8',
  navy: '#1f3b4f',
  skin: '#e8956b', skinShade: '#c9714f', skinDeep: '#a85a3e', flush: '#dd5f4f',
  hair: '#3b2a22',
  shirt: '#3e6e68', shirtShade: '#2d5550', shirtLight: '#4f817a', sweatPatch: '#28504b',
  tee: '#f4ede4', pants: '#2b3140', boot: '#4a3426',
  cap: '#c75a2e', capShade: '#a04420',
  box: '#dfa13b', boxSide: '#b9802a', boxTop: '#ebb757', tape: '#7a5532',
  sweat: '#f2fbff', sweatBlue: '#cdeaff',
  beltTop: '#2f4356', beltStripe: '#3b5268', rail: '#8ea4b7', railLight: '#b5c6d5',
  roller: '#677e92', leg: '#4f6579',
};

const drop = (x, y, s = 1, r = 0, color = C.sweat) =>
  `<path transform="translate(${x} ${y}) rotate(${r}) scale(${s})" d="M0 -22 C 9 -8 14 2 14 10 A 14 14 0 1 1 -14 10 C -14 2 -9 -8 0 -22 Z" fill="${color}"/>`;

// Flat cardboard box. (x, y) is the bottom-left of the front face.
function box(x, y, w, h, { rot = 0, d = 0.3, tape = true } = {}) {
  const dx = w * d * 0.55, dy = w * d * 0.4, top = y - h, cx = x + w / 2;
  let s = `<g transform="rotate(${rot} ${cx} ${y - h / 2})">`;
  s += `<path d="M${x} ${top} l${dx} ${-dy} h${w} l${-dx} ${dy} Z" fill="${C.boxTop}"/>`;
  s += `<path d="M${x + w} ${top} l${dx} ${-dy} v${h} l${-dx} ${dy} Z" fill="${C.boxSide}"/>`;
  s += `<rect x="${x}" y="${top}" width="${w}" height="${h}" fill="${C.box}"/>`;
  s += `<rect x="${x}" y="${y - h * 0.1}" width="${w}" height="${h * 0.1}" fill="${C.boxSide}" opacity=".35"/>`;
  if (tape) {
    const tw = Math.max(10, w * 0.09);
    s += `<path d="M${cx - tw / 2} ${top} l${dx} ${-dy} h${tw} l${-dx} ${dy} Z" fill="${C.tape}"/>`;
    s += `<rect x="${cx - tw / 2}" y="${top}" width="${tw}" height="${h * 0.3}" fill="${C.tape}"/>`;
    s += `<rect x="${x}" y="${y - h * 0.24}" width="${tw * 0.9}" height="${h * 0.24}" fill="${C.tape}"/>`;
    s += `<rect x="${x + w - tw * 0.9}" y="${y - h * 0.24}" width="${tw * 0.9}" height="${h * 0.24}" fill="${C.tape}"/>`;
  }
  return s + '</g>';
}

// The worker, turned three-quarters to the left, hoisting a box off the belt.
// Origin = base of the neck.
function worker() {
  let s = '<g>';
  // legs (mostly hidden behind the belt)
  s += `<path d="M-115 360 L110 360 L120 760 L30 760 L5 470 L-20 760 L-110 760 Z" fill="${C.pants}"/>`;
  s += `<path d="M-125 740 h105 v40 h-130 q-5 -40 25 -40 Z M25 740 h105 q25 0 25 40 h-130 Z" fill="${C.boot}"/>`;
  // far arm (behind the torso), reaching to the far side of the box
  s += `<path d="M-120 40 Q-190 70 -205 190 L-150 200 Q-140 110 -95 80 Z" fill="${C.shirtShade}"/>`;
  s += `<path d="M-200 175 Q-235 250 -255 300 L-215 318 Q-190 260 -158 190 Z" fill="${C.skinShade}"/>`;
  // torso
  s += `<path d="M-128 28 Q-60 -8 0 0 Q70 -6 128 30 Q160 120 140 380 L-120 380 Q-150 200 -128 28 Z" fill="${C.shirt}"/>`;
  s += `<path d="M40 2 Q100 0 128 30 Q160 120 140 380 L60 380 Q90 200 40 2 Z" fill="${C.shirtShade}"/>`;
  s += `<ellipse cx="96" cy="120" rx="30" ry="50" fill="${C.sweatPatch}"/>`;
  s += `<ellipse cx="-20" cy="70" rx="46" ry="28" fill="${C.sweatPatch}" opacity=".7"/>`;
  // undershirt V, collar, buttons
  s += `<path d="M-40 0 L-8 66 L22 0 Z" fill="${C.tee}"/>`;
  s += `<path d="M-58 -6 L-10 58 L-26 74 L-72 14 Z" fill="${C.shirtLight}"/><path d="M40 -6 L-6 58 L8 72 L56 12 Z" fill="${C.shirtLight}"/>`;
  s += `<circle cx="-6" cy="96" r="6" fill="${C.skinShade}"/><circle cx="-6" cy="124" r="6" fill="${C.skinShade}"/>`;
  // neck
  s += `<path d="M-38 -70 L28 -70 L22 4 Q-6 22 -36 4 Z" fill="${C.skinShade}"/>`;
  // head
  s += `<path d="M-60 -238 Q-10 -262 44 -232 Q72 -200 64 -150 Q60 -110 40 -86 Q18 -54 -22 -48 Q-56 -46 -70 -64 L-76 -92 Q-90 -100 -84 -112 L-92 -124 Q-104 -128 -100 -138 L-84 -170 Q-84 -208 -60 -238 Z" fill="${C.skin}"/>`;
  s += `<path d="M18 -230 Q72 -200 64 -150 Q60 -110 40 -86 Q18 -54 -22 -48 Q20 -80 22 -130 Q24 -190 18 -230 Z" fill="${C.skinShade}"/>`;
  s += `<ellipse cx="34" cy="-140" rx="15" ry="24" fill="${C.skinDeep}"/>`;
  s += `<ellipse cx="-36" cy="-118" rx="24" ry="13" fill="${C.flush}" opacity=".55"/>`;
  s += `<ellipse cx="-30" cy="-200" rx="36" ry="10" fill="${C.flush}" opacity=".3"/>`;
  // nose shadow
  s += `<path d="M-76 -170 L-98 -134 L-80 -126 Z" fill="${C.skinShade}"/>`;
  // worried brows (inner ends raised)
  s += `<path d="M-60 -190 L-20 -178 L-22 -170 L-58 -180 Z" fill="${C.hair}"/>`;
  s += `<path d="M-92 -176 L-70 -190 L-68 -182 L-88 -170 Z" fill="${C.hair}"/>`;
  // eyes, darting toward the incoming boxes
  s += `<ellipse cx="-40" cy="-160" rx="13" ry="9" fill="${C.tee}"/><circle cx="-46" cy="-159" r="5.5" fill="${C.hair}"/>`;
  s += `<ellipse cx="-80" cy="-158" rx="7" ry="8" fill="${C.tee}"/><circle cx="-83" cy="-157" r="4" fill="${C.hair}"/>`;
  s += `<path d="M-54 -146 Q-40 -140 -26 -146" stroke="${C.skinShade}" stroke-width="4" fill="none" stroke-linecap="round"/>`;
  // grimace: open mouth, clenched teeth, mustache on top
  s += `<path d="M-92 -98 Q-62 -106 -34 -100 L-38 -80 Q-62 -86 -88 -78 Z" fill="${C.tee}"/>`;
  s += `<path d="M-90 -88 Q-62 -94 -36 -90" stroke="#6c2a22" stroke-width="4" fill="none"/>`;
  s += `<path d="M-76 -102 V-80 M-62 -104 V-84 M-48 -102 V-82" stroke="#cfc4b8" stroke-width="2.5"/>`;
  s += `<path d="M-30 -100 Q-30 -88 -26 -80" stroke="${C.skinShade}" stroke-width="4" fill="none" stroke-linecap="round"/>`;
  s += `<path d="M-100 -118 Q-84 -126 -66 -120 Q-48 -128 -32 -112 Q-50 -106 -66 -110 Q-86 -104 -100 -118 Z" fill="${C.hair}"/>`;
  // cap with the bill pointing at the belt
  s += `<path d="M-84 -196 Q-90 -262 -20 -272 Q50 -276 70 -210 Q72 -186 62 -176 Q-10 -206 -84 -196 Z" fill="${C.cap}"/>`;
  s += `<path d="M20 -268 Q64 -250 70 -210 Q72 -186 62 -176 Q40 -186 22 -192 Q36 -230 20 -268 Z" fill="${C.capShade}"/>`;
  s += `<path d="M-74 -200 Q-120 -204 -156 -186 Q-150 -176 -120 -178 Q-96 -184 -70 -186 Z" fill="${C.capShade}"/>`;
  s += `<circle cx="-14" cy="-272" r="7" fill="${C.capShade}"/>`;
  // sweat: beads, a trickle and drops flying off
  s += `<path d="M10 -190 Q16 -150 8 -112" stroke="${C.sweatBlue}" stroke-width="7" fill="none" stroke-linecap="round"/>`;
  s += drop(8, -104, 0.55) + drop(-12, -146, 0.45) + drop(-62, -132, 0.4) + drop(-100, -150, 0.4);
  s += drop(-150, -250, 1, -30) + drop(-170, -150, 0.85, -65) + drop(-124, -320, 0.8, -15);
  s += drop(100, -270, 1, 30) + drop(118, -180, 0.8, 60) + drop(40, -326, 0.75, 10);
  return s + '</g>';
}

// Near arm + box drawn in front of the torso, separate so the belt can sit between.
function workerFront() {
  let s = '';
  s += box(-300, 330, 250, 180, { d: 0.28 });
  // far hand gripping the left edge
  s += `<rect x="-312" y="208" width="40" height="78" rx="18" fill="${C.skinShade}"/>`;
  s += `<path d="M-300 230 h22 M-300 248 h22 M-300 266 h22" stroke="${C.skinDeep}" stroke-width="3.5" stroke-linecap="round"/>`;
  // near arm: sleeve, forearm, hand under the box
  s += `<path d="M96 30 Q150 50 156 150 Q150 200 120 215 L72 190 Q90 120 70 60 Z" fill="${C.shirt}"/>`;
  s += `<path d="M120 200 Q104 260 30 296 L-30 310 L-36 280 L16 258 Q70 230 80 190 Z" fill="${C.skin}"/>`;
  s += `<path d="M-70 334 Q-80 300 -50 284 L4 278 Q20 296 4 318 Q-30 340 -70 334 Z" fill="${C.skin}"/>`;
  s += `<path d="M-40 300 L-12 296 M-46 314 L-14 310" stroke="${C.skinShade}" stroke-width="4" stroke-linecap="round"/>`;
  return s;
}

function conveyor(x0, x1, y, floorY) {
  let s = '';
  for (let x = x0 + 70; x < x1; x += 240) s += `<rect x="${x}" y="${y + 70}" width="28" height="${floorY - y - 70}" fill="${C.leg}"/>`;
  s += `<rect x="${x0}" y="${y - 18}" width="${x1 - x0}" height="34" fill="${C.beltTop}"/>`;
  for (let x = x0; x < x1; x += 44) s += `<rect x="${x}" y="${y - 18}" width="14" height="34" fill="${C.beltStripe}" transform="skewX(-20)" transform-origin="${x} ${y}"/>`;
  s += `<rect x="${x0}" y="${y + 14}" width="${x1 - x0}" height="62" fill="${C.rail}"/>`;
  s += `<rect x="${x0}" y="${y + 14}" width="${x1 - x0}" height="12" fill="${C.railLight}"/>`;
  for (let x = x0 + 50; x < x1; x += 120) s += `<circle cx="${x}" cy="${y + 50}" r="14" fill="${C.roller}"/>`;
  return s;
}

const speed = (x, y, h, n = 3, color = '#ffffff') => {
  let s = '';
  for (let i = 0; i < n; i++) {
    const yy = y - h * (0.25 + 0.28 * i);
    s += `<rect x="${x - 110 - i * 30}" y="${yy - 4}" width="${80 + i * 14}" height="8" rx="4" fill="${color}" opacity=".5"/>`;
  }
  return s;
};

const defs = (withFont) => `<defs>
  ${withFont ? `<style>@font-face{font-family:Lexend;font-weight:700;src:url(data:font/ttf;base64,${FONT})}</style>` : ''}
  <filter id="grain" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency=".85" numOctaves="3" seed="7" stitchTiles="stitch"/>
    <feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -1.6 1.25"/>
  </filter>
  <radialGradient id="vignette" cx=".5" cy=".45" r=".75"><stop offset=".6" stop-color="#0b2236" stop-opacity="0"/><stop offset="1" stop-color="#0b2236" stop-opacity=".22"/></radialGradient>
</defs>`;

const grain = (w, h, o = 0.16) =>
  `<rect width="${w}" height="${h}" fill="url(#vignette)"/><rect width="${w}" height="${h}" filter="url(#grain)" opacity="${o}" style="mix-blend-mode:multiply"/>`;

function homeScreen(withTitle) {
  const W = 1080, H = 1920, beltY = 1330, floorY = 1700;
  let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${defs(withTitle)}`;
  s += `<rect width="${W}" height="${H}" fill="${C.bg}"/>`;
  // pale backdrop shapes
  s += `<path d="M150 ${H} Q120 820 560 760 Q1000 740 990 ${H} Z" fill="${C.blob}" opacity=".85"/>`;
  s += `<circle cx="40" cy="760" r="110" fill="${C.blobSoft}"/><path d="M60 1010 a80 80 0 1 0 0 1 Z" fill="${C.blobSoft}"/>`;
  s += `<path d="M900 640 L1010 560 L1010 700 Z" fill="${C.blobSoft}"/><path d="M960 900 l70 -80 l20 110 Z" fill="${C.blobSoft}"/>`;
  // stacked boxes silhouettes far behind
  for (const [x, y, w, h] of [[30, 1240, 170, 120], [60, 1120, 120, 120], [870, 1250, 190, 130], [900, 1130, 140, 120]])
    s += `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${C.blobSoft}"/>`;
  // floor
  s += `<rect x="0" y="${floorY}" width="${W}" height="${H - floorY}" fill="${C.bgDeep}"/>`;
  s += `<ellipse cx="560" cy="${floorY + 10}" rx="300" ry="34" fill="#3f7fae" opacity=".55"/>`;
  // worker behind the belt
  s += `<g transform="translate(600 890) scale(1.1)">${worker()}</g>`;
  s += conveyor(-20, W + 20, beltY, floorY + 10);
  s += `<g transform="translate(600 890) scale(1.1)">${workerFront()}</g>`;
  // boxes speeding in from the left, more piling up on the right
  s += speed(40, beltY - 18, 120) + box(30, beltY - 6, 150, 120);
  s += speed(250, beltY - 18, 90, 2) + box(240, beltY - 6, 110, 90, { rot: -3 });
  s += box(800, beltY - 6, 150, 110, { rot: 2 }) + box(950, beltY - 6, 110, 120, { rot: -4 });
  s += box(830, beltY - 120, 120, 100, { rot: -8 }) + box(960, beltY - 135, 100, 80, { rot: 12 });
  // one going over the edge
  s += box(1000, 1530, 120, 100, { rot: 30 });
  // fallen boxes on the floor
  s += box(70, 1880, 180, 130, { rot: -6 }) + box(820, 1880, 170, 120, { rot: 5 });
  s += grain(W, H);

  if (withTitle) {
    const font = 'font-family="Lexend, Liberation Sans, sans-serif" font-weight="700" text-anchor="middle"';
    s += `<text x="540" y="300" ${font} font-size="170" letter-spacing="4" fill="${C.navy}">PRELOAD</text>`;
    s += `<text x="540" y="390" ${font} font-size="54" letter-spacing="10" fill="#ffffff">RUSH HOUR</text>`;
    s += `<rect x="300" y="1745" width="480" height="104" rx="52" fill="${C.navy}"/>`;
    s += `<text x="540" y="1814" ${font} font-size="44" letter-spacing="3" fill="#ffffff">TAP TO START</text>`;
  }
  return s + '</svg>';
}

function appIcon() {
  const S = 1024;
  let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">${defs(false)}`;
  s += `<rect width="${S}" height="${S}" fill="${C.bg}"/>`;
  s += `<circle cx="560" cy="560" r="400" fill="${C.blob}"/>`;
  s += `<circle cx="90" cy="180" r="70" fill="${C.blobSoft}"/><path d="M900 120 L990 60 L990 200 Z" fill="${C.blobSoft}"/>`;
  s += `<g transform="translate(600 520) scale(1.3)">${worker()}</g>`;
  s += conveyor(-20, S + 20, 900, 1100);
  s += `<g transform="translate(600 520) scale(1.3)">${workerFront()}</g>`;
  s += speed(70, 882, 110, 2) + box(40, 894, 130, 100);
  s += grain(S, S, 0.14);
  return s + '</svg>';
}

(async () => {
  const files = {
    'home_screen.svg': homeScreen(false),
    'home_screen_titled.svg': homeScreen(true),
    'app_icon.svg': appIcon(),
  };
  for (const [name, svg] of Object.entries(files)) fs.writeFileSync(path.join(OUT, name), svg);

  const { chromium } = require('playwright');
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const render = async (svg, w, h, file) => {
    await page.setViewportSize({ width: w, height: h });
    await page.setContent(`<html><body style="margin:0">${svg.replace(/width="\d+" height="\d+"/, `width="${w}" height="${h}"`)}</body></html>`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(OUT, file) });
  };
  await render(files['home_screen.svg'], 1080, 1920, 'home_screen.png');
  await render(files['home_screen_titled.svg'], 1080, 1920, 'home_screen_titled.png');
  for (const size of [1024, 512, 192, 180, 120])
    await render(files['app_icon.svg'], size, size, size === 1024 ? 'app_icon.png' : `app_icon_${size}.png`);
  await browser.close();
})();
