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
  skin: '#8a5636', skinShade: '#6c3f25', skinDeep: '#54301c', flush: '#a8473a',
  hair: '#1b1210', mouth: '#3a1712',
  shirt: '#6b4a2b', shirtShade: '#553a21', shirtLight: '#7d5935', sweatPatch: '#46301b', button: '#b88a5a',
  tee: '#f4ede4', pants: '#5a3f25', boot: '#2b1d14',
  cap: '#6b4a2b', capShade: '#553a21',
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

// Open hand at the wrist (x, y), fingers splayed toward `angle` (degrees, 0 = up).
function hand(x, y, angle, color, lineColor, flip = 1) {
  let s = `<g transform="translate(${x} ${y}) rotate(${angle}) scale(${flip} 1)">`;
  for (const [fx, fy, len, a] of [[-16, -26, 34, -18], [-5, -30, 40, -6], [7, -30, 38, 6], [17, -25, 30, 18]])
    s += `<path d="M${fx} ${fy} l${Math.sin(a * Math.PI / 180) * len} ${-Math.cos(a * Math.PI / 180) * len}" stroke="${color}" stroke-width="13" stroke-linecap="round"/>`;
  s += `<path d="M-20 -8 l-26 -20" stroke="${color}" stroke-width="13" stroke-linecap="round"/>`;
  s += `<ellipse cx="0" cy="-12" rx="25" ry="27" fill="${color}"/>`;
  s += `<path d="M-10 -20 Q0 -10 12 -22" stroke="${lineColor}" stroke-width="3.5" fill="none" stroke-linecap="round"/>`;
  return s + '</g>';
}

// Arm from shoulder through elbow to wrist: short sleeve, then bare arm, then an open hand.
function arm([sx, sy], [ex, ey], [wx, wy], shirt, skin, line, handAngle, flip) {
  const mx = sx + (ex - sx) * 0.55, my = sy + (ey - sy) * 0.55;
  let s = `<path d="M${mx} ${my} L${ex} ${ey} L${wx} ${wy}" stroke="${skin}" stroke-width="44" stroke-linecap="round" stroke-linejoin="round" fill="none"/>`;
  s += `<path d="M${sx} ${sy} L${mx} ${my}" stroke="${shirt}" stroke-width="66" stroke-linecap="round" fill="none"/>`;
  return s + hand(wx, wy, handAngle, skin, line, flip);
}

// The worker, three-quarters to the left, head thrown back and both hands up in
// frustration. Origin = base of the neck.
function worker() {
  let s = '<g>';
  // legs (mostly hidden behind the belt)
  s += `<path d="M-115 360 L110 360 L120 760 L30 760 L5 470 L-20 760 L-110 760 Z" fill="${C.pants}"/>`;
  s += `<path d="M-125 740 h105 v40 h-130 q-5 -40 25 -40 Z M25 740 h105 q25 0 25 40 h-130 Z" fill="${C.boot}"/>`;
  // far arm, behind the torso
  s += arm([-105, 45], [-240, -45], [-272, -205], C.shirtShade, C.skinShade, C.skinDeep, -14, -1);
  // torso
  s += `<path d="M-128 28 Q-60 -8 0 0 Q70 -6 128 30 Q160 120 140 380 L-120 380 Q-150 200 -128 28 Z" fill="${C.shirt}"/>`;
  s += `<path d="M40 2 Q100 0 128 30 Q160 120 140 380 L60 380 Q90 200 40 2 Z" fill="${C.shirtShade}"/>`;
  s += `<ellipse cx="104" cy="96" rx="28" ry="46" fill="${C.sweatPatch}"/>`;
  s += `<ellipse cx="-20" cy="70" rx="46" ry="28" fill="${C.sweatPatch}" opacity=".7"/>`;
  s += `<path d="M-100 330 L120 330" stroke="${C.shirtShade}" stroke-width="10"/>`;
  // undershirt V, collar, buttons
  s += `<path d="M-40 0 L-8 66 L22 0 Z" fill="${C.tee}"/>`;
  s += `<path d="M-58 -6 L-10 58 L-26 74 L-72 14 Z" fill="${C.shirtLight}"/><path d="M40 -6 L-6 58 L8 72 L56 12 Z" fill="${C.shirtLight}"/>`;
  s += `<circle cx="-6" cy="96" r="6" fill="${C.button}"/><circle cx="-6" cy="124" r="6" fill="${C.button}"/>`;
  // near arm, in front of the torso
  s += arm([105, 40], [225, -55], [232, -218], C.shirt, C.skin, C.skinShade, 10, 1);
  // neck
  s += `<path d="M-38 -70 L28 -70 L22 4 Q-6 22 -36 4 Z" fill="${C.skinShade}"/>`;
  // head, turned square to the camera: he's looking right at the player
  s += `<ellipse cx="-78" cy="-150" rx="14" ry="22" fill="${C.skin}"/><ellipse cx="78" cy="-150" rx="14" ry="22" fill="${C.skinShade}"/>`;
  s += `<path d="M0 -258 C60 -258 80 -212 78 -160 C76 -110 58 -70 0 -48 C-58 -70 -76 -110 -78 -160 C-80 -212 -60 -258 0 -258 Z" fill="${C.skin}"/>`;
  s += `<path d="M30 -250 C68 -236 80 -204 78 -160 C76 -110 58 -70 0 -48 C40 -80 52 -120 50 -160 C48 -200 44 -230 30 -250 Z" fill="${C.skinShade}"/>`;
  s += `<path d="M-58 -94 C-44 -68 -22 -56 0 -53 C22 -56 44 -68 58 -94 C40 -80 20 -76 0 -76 C-20 -76 -40 -80 -58 -94 Z" fill="${C.skinDeep}" opacity=".4"/>`;
  s += `<ellipse cx="-44" cy="-124" rx="18" ry="10" fill="${C.flush}" opacity=".45"/><ellipse cx="44" cy="-124" rx="18" ry="10" fill="${C.flush}" opacity=".35"/>`;
  // one brow cocked, one flat: "you seeing this?"
  s += `<path d="M-56 -188 Q-36 -206 -14 -192" stroke="${C.hair}" stroke-width="10" fill="none" stroke-linecap="round"/>`;
  s += `<path d="M14 -180 L56 -184" stroke="${C.hair}" stroke-width="10" fill="none" stroke-linecap="round"/>`;
  // eyes locked on the viewer, lids half down
  for (const [x, lid] of [[-34, -172], [34, -167]]) {
    s += `<ellipse cx="${x}" cy="-160" rx="15" ry="11" fill="${C.tee}"/><circle cx="${x}" cy="-158" r="7" fill="${C.hair}"/><circle cx="${x - 2}" cy="-161" r="2" fill="#fff"/>`;
    s += `<path d="M${x - 17} -160 Q${x} ${lid - 6} ${x + 17} -160 L${x + 17} -174 L${x - 17} -174 Z" fill="${C.skinShade}"/>`;
    s += `<path d="M${x - 16} ${lid + 2} Q${x} ${lid - 4} ${x + 16} ${lid + 2}" stroke="${C.skinDeep}" stroke-width="3" fill="none"/>`;
    s += `<path d="M${x - 12} -144 Q${x} -140 ${x + 12} -144" stroke="${C.skinShade}" stroke-width="3.5" fill="none" stroke-linecap="round"/>`;
  }
  // nose
  s += `<path d="M-4 -152 L-14 -114 Q0 -106 16 -114 L8 -150 Z" fill="${C.skinShade}"/>`;
  s += `<path d="M-12 -112 Q0 -106 14 -112" stroke="${C.skinDeep}" stroke-width="4" fill="none" stroke-linecap="round"/>`;
  // clenched, downturned grimace under the mustache
  s += `<path d="M-36 -78 Q0 -96 36 -78 Q32 -62 0 -64 Q-32 -62 -36 -78 Z" fill="${C.mouth}"/>`;
  s += `<path d="M-32 -78 Q0 -94 32 -78 L30 -70 Q0 -84 -30 -70 Z" fill="${C.tee}"/>`;
  s += `<path d="M-14 -84 V-74 M0 -87 V-77 M14 -84 V-74" stroke="#cfc4b8" stroke-width="2.5"/>`;
  s += `<path d="M-42 -96 Q-20 -110 0 -100 Q20 -110 42 -96 Q22 -86 0 -92 Q-22 -86 -42 -96 Z" fill="${C.hair}"/>`;
  // cap, seen from the front, bill curving down toward the viewer
  s += `<path d="M-80 -214 Q-84 -290 0 -296 Q84 -290 80 -214 Q0 -232 -80 -214 Z" fill="${C.cap}"/>`;
  s += `<path d="M20 -294 Q82 -282 80 -214 Q60 -220 40 -224 Q50 -262 20 -294 Z" fill="${C.capShade}"/>`;
  s += `<path d="M-100 -216 Q0 -250 100 -216 Q108 -196 90 -190 Q0 -220 -90 -190 Q-108 -196 -100 -216 Z" fill="${C.capShade}"/>`;
  s += `<path d="M-84 -203 Q0 -228 84 -203" stroke="${C.cap}" stroke-width="4" fill="none" opacity=".7"/>`;
  s += `<circle cx="0" cy="-296" r="8" fill="${C.capShade}"/>`;
  // sweat on the face
  s += `<path d="M62 -192 Q70 -150 62 -118" stroke="${C.sweatBlue}" stroke-width="7" fill="none" stroke-linecap="round"/>`;
  s += drop(62, -110, 0.55) + drop(-64, -180, 0.42) + drop(-58, -132, 0.4) + drop(0, -180, 0.38);
  // drops flying off
  s += drop(-150, -300, 0.9, -30) + drop(-175, -200, 0.8, -60) + drop(-90, -370, 0.75, -15);
  s += drop(120, -300, 0.9, 30) + drop(140, -200, 0.75, 60) + drop(30, -390, 0.7, 10);
  // frustration marks by the hands
  for (const [x1, y1, x2, y2] of [[-330, -270, -360, -300], [-345, -215, -385, -222], [290, -280, 318, -312], [305, -225, 345, -232]])
    s += `<path d="M${x1} ${y1} L${x2} ${y2}" stroke="#ffffff" stroke-width="9" stroke-linecap="round" opacity=".75"/>`;
  return s + '</g>';
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
  s += speed(470, beltY - 18, 140) + box(470, beltY - 6, 210, 150, { rot: -2 });
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
  s += `<g transform="translate(590 575) scale(1.22)">${worker()}</g>`;
  s += conveyor(-20, S + 20, 900, 1100);
  s += speed(70, 882, 110, 2) + box(40, 894, 130, 100) + box(600, 894, 230, 160, { rot: 2 });
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
