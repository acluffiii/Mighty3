// Generates the Preload game home screen and app icon as SVG + PNG.
// Usage: node generate.js   (needs the globally installed `playwright` package)
const fs = require('fs');
const path = require('path');

const OUT = path.resolve(__dirname, '..');
const FONT = fs.readFileSync(path.join(__dirname, 'Bungee-Regular.ttf')).toString('base64');

const C = {
  skin: '#f0a97c', skinShade: '#d9875a', flush: '#ff4d4d',
  shirt: '#2f6fb3', shirtDark: '#1f4f85', sweatPatch: '#24568f',
  vest: '#ffb703', vestDark: '#e09600', reflect: '#e8eef5',
  cap: '#d62828', capDark: '#9d1c1c',
  ink: '#1d1b26',
  box: '#c98f4f', boxTop: '#dcaa6c', boxSide: '#a8733a', tape: '#e9c88f',
  sweat: '#8fdcff', sweatStroke: '#2a7fbf',
};

const drop = (x, y, s = 1, r = 0) =>
  `<path transform="translate(${x} ${y}) rotate(${r}) scale(${s})" d="M0 -20 C 9 -7 13 2 13 9 A 13 13 0 1 1 -13 9 C -13 2 -9 -7 0 -20 Z" fill="${C.sweat}" stroke="${C.sweatStroke}" stroke-width="3"/>` +
  `<ellipse transform="translate(${x} ${y}) rotate(${r}) scale(${s})" cx="-4" cy="6" rx="3" ry="5" fill="#fff" opacity=".8"/>`;

// A cardboard box with a visible top face. (x, y) is the bottom-left of the front face.
function box(x, y, w, h, { rot = 0, label = true, depth = 0.35, fragile = false } = {}) {
  const d = w * depth;
  const top = y - h;
  const cx = x + w / 2;
  let s = `<g transform="rotate(${rot} ${cx} ${y - h / 2})">`;
  s += `<path d="M${x} ${top} L${x + d * 0.5} ${top - d * 0.45} L${x + w + d * 0.5} ${top - d * 0.45} L${x + w} ${top} Z" fill="${C.boxTop}" stroke="${C.ink}" stroke-width="4" stroke-linejoin="round"/>`;
  s += `<path d="M${x + w} ${top} L${x + w + d * 0.5} ${top - d * 0.45} L${x + w + d * 0.5} ${y - d * 0.45} L${x + w} ${y} Z" fill="${C.boxSide}" stroke="${C.ink}" stroke-width="4" stroke-linejoin="round"/>`;
  s += `<rect x="${x}" y="${top}" width="${w}" height="${h}" fill="${C.box}" stroke="${C.ink}" stroke-width="4" stroke-linejoin="round"/>`;
  // tape across the top and down the front
  s += `<path d="M${cx - w * 0.07} ${top} L${cx - w * 0.07 + d * 0.5} ${top - d * 0.45} L${cx + w * 0.07 + d * 0.5} ${top - d * 0.45} L${cx + w * 0.07} ${top} Z" fill="${C.tape}" opacity=".9"/>`;
  s += `<rect x="${cx - w * 0.07}" y="${top + 2}" width="${w * 0.14}" height="${h * 0.32}" fill="${C.tape}" opacity=".9"/>`;
  if (label && w > 60) {
    const lw = w * 0.42, lh = h * 0.3, lx = x + w * 0.08, ly = y - lh - h * 0.12;
    s += `<rect x="${lx}" y="${ly}" width="${lw}" height="${lh}" rx="3" fill="#fbfbf6" stroke="${C.ink}" stroke-width="2.5"/>`;
    for (let i = 0; i < 7; i++) {
      const bx = lx + lw * 0.1 + i * lw * 0.115;
      s += `<rect x="${bx}" y="${ly + lh * 0.45}" width="${i % 3 === 0 ? lw * 0.06 : lw * 0.03}" height="${lh * 0.4}" fill="${C.ink}"/>`;
    }
    s += `<rect x="${lx + lw * 0.1}" y="${ly + lh * 0.15}" width="${lw * 0.6}" height="${lh * 0.12}" fill="${C.ink}" opacity=".6"/>`;
  }
  if (fragile) {
    const fx = x + w * 0.62, fy = y - h * 0.62, fs = Math.min(w, h) * 0.16;
    s += `<path d="M${fx} ${fy + fs * 1.4} V${fy} M${fx - fs * 0.6} ${fy + fs * 0.6} L${fx} ${fy} L${fx + fs * 0.6} ${fy + fs * 0.6}" fill="none" stroke="${C.capDark}" stroke-width="${fs * 0.28}" stroke-linecap="round" stroke-linejoin="round"/>`;
    s += `<path d="M${fx + fs * 1.1} ${fy + fs * 1.4} V${fy} M${fx + fs * 0.5} ${fy + fs * 0.6} L${fx + fs * 1.1} ${fy} L${fx + fs * 1.7} ${fy + fs * 0.6}" fill="none" stroke="${C.capDark}" stroke-width="${fs * 0.28}" stroke-linecap="round" stroke-linejoin="round"/>`;
  }
  return s + '</g>';
}

// The stressed preload worker. Origin = center of his face. Holds a box at chest height.
function worker() {
  let s = '<g>';
  // torso
  s += `<path d="M-150 175 Q-160 130 -105 112 L105 112 Q160 130 150 175 L172 560 L-172 560 Z" fill="${C.shirt}" stroke="${C.ink}" stroke-width="6" stroke-linejoin="round"/>`;
  // sweat patches
  s += `<ellipse cx="-128" cy="215" rx="26" ry="42" fill="${C.sweatPatch}"/><ellipse cx="128" cy="215" rx="26" ry="42" fill="${C.sweatPatch}"/>`;
  s += `<ellipse cx="0" cy="160" rx="40" ry="28" fill="${C.sweatPatch}"/>`;
  // safety vest
  s += `<path d="M-108 116 L-40 116 L-8 260 L-8 560 L-150 560 L-140 190 Q-145 140 -108 116 Z" fill="${C.vest}" stroke="${C.ink}" stroke-width="5" stroke-linejoin="round"/>`;
  s += `<path d="M108 116 L40 116 L8 260 L8 560 L150 560 L140 190 Q145 140 108 116 Z" fill="${C.vest}" stroke="${C.ink}" stroke-width="5" stroke-linejoin="round"/>`;
  s += `<rect x="-148" y="430" width="140" height="26" fill="${C.reflect}" stroke="${C.ink}" stroke-width="3"/><rect x="8" y="430" width="140" height="26" fill="${C.reflect}" stroke="${C.ink}" stroke-width="3"/>`;
  s += `<path d="M-96 125 L-30 125 L-22 160 L-103 160 Z" fill="${C.reflect}" stroke="${C.ink}" stroke-width="3"/><path d="M96 125 L30 125 L22 160 L103 160 Z" fill="${C.reflect}" stroke="${C.ink}" stroke-width="3"/>`;
  // neck
  s += `<path d="M-42 70 L-42 125 Q0 150 42 125 L42 70 Z" fill="${C.skinShade}" stroke="${C.ink}" stroke-width="5"/>`;
  // legs + boots (mostly hidden behind the belt)
  for (const k of [-1, 1]) {
    s += `<path d="M${k * 20} 540 L${k * 150} 540 L${k * 140} 705 L${k * 40} 705 Z" fill="#2b3550" stroke="${C.ink}" stroke-width="6" stroke-linejoin="round"/>`;
    s += `<path d="M${k * 30} 700 L${k * 150} 700 Q${k * 185} 705 ${k * 185} 745 L${k * 30} 745 Z" fill="#5a3b24" stroke="${C.ink}" stroke-width="6" stroke-linejoin="round"/>`;
  }
  // arms: sleeves then forearms bent up to chest height (behind the box)
  for (const k of [-1, 1]) {
    s += `<path d="M${k * 135} 150 Q${k * 210} 190 ${k * 215} 270" fill="none" stroke="${C.ink}" stroke-width="82" stroke-linecap="round"/>`;
    s += `<path d="M${k * 135} 150 Q${k * 210} 190 ${k * 215} 270" fill="none" stroke="${C.shirt}" stroke-width="70" stroke-linecap="round"/>`;
    s += `<path d="M${k * 182} 240 Q${k * 215} 252 ${k * 248} 240" fill="none" stroke="${C.shirtDark}" stroke-width="10" stroke-linecap="round"/>`;
    s += `<path d="M${k * 218} 285 Q${k * 225} 330 ${k * 165} 300" fill="none" stroke="${C.ink}" stroke-width="64" stroke-linecap="round"/>`;
    s += `<path d="M${k * 218} 285 Q${k * 225} 330 ${k * 165} 300" fill="none" stroke="${C.skin}" stroke-width="52" stroke-linecap="round"/>`;
  }
  // the box he's straining with, hoisted to his chest
  s += box(-150, 375, 300, 200, { depth: 0.25, fragile: true });
  // hands gripping the sides
  for (const k of [-1, 1]) {
    s += `<ellipse cx="${k * 150}" cy="285" rx="34" ry="44" fill="${C.skin}" stroke="${C.ink}" stroke-width="5"/>`;
    s += `<path d="M${k * 125} 265 h${k * -18} M${k * 125} 287 h${k * -20} M${k * 125} 309 h${k * -16}" stroke="${C.ink}" stroke-width="4" stroke-linecap="round"/>`;
  }
  // head
  s += `<circle cx="-106" cy="12" r="26" fill="${C.skin}" stroke="${C.ink}" stroke-width="5"/><circle cx="106" cy="12" r="26" fill="${C.skin}" stroke="${C.ink}" stroke-width="5"/>`;
  s += `<ellipse cx="0" cy="0" rx="106" ry="112" fill="${C.skin}" stroke="${C.ink}" stroke-width="6"/>`;
  // red-faced flush
  s += `<ellipse cx="-58" cy="48" rx="28" ry="17" fill="${C.flush}" opacity=".45"/><ellipse cx="58" cy="48" rx="28" ry="17" fill="${C.flush}" opacity=".45"/>`;
  s += `<ellipse cx="0" cy="-48" rx="70" ry="24" fill="${C.flush}" opacity=".18"/>`;
  // stubble
  s += `<path d="M-80 60 Q0 140 80 60 Q60 112 0 112 Q-60 112 -80 60 Z" fill="#6b4a3a" opacity=".18"/>`;
  // backwards cap
  s += `<path d="M-104 -30 Q-108 -128 0 -132 Q108 -128 104 -30 Q0 -58 -104 -30 Z" fill="${C.cap}" stroke="${C.ink}" stroke-width="6" stroke-linejoin="round"/>`;
  s += `<path d="M-40 -42 Q0 -52 40 -42" fill="none" stroke="${C.capDark}" stroke-width="8" stroke-linecap="round"/>`;
  s += `<path d="M-75 -110 Q-55 -125 -30 -128" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" opacity=".45"/>`;
  s += `<circle cx="0" cy="-132" r="9" fill="${C.capDark}" stroke="${C.ink}" stroke-width="4"/>`;
  // forehead wrinkles
  s += `<path d="M-38 -24 Q0 -32 38 -24" fill="none" stroke="${C.skinShade}" stroke-width="5" stroke-linecap="round"/>`;
  // worried brows
  s += `<path d="M-78 -2 L-20 -22" stroke="${C.ink}" stroke-width="13" stroke-linecap="round"/><path d="M78 -2 L20 -22" stroke="${C.ink}" stroke-width="13" stroke-linecap="round"/>`;
  // eyes, glancing at the incoming boxes
  for (const k of [-1, 1]) {
    s += `<ellipse cx="${k * 42}" cy="22" rx="24" ry="27" fill="#fff" stroke="${C.ink}" stroke-width="5"/>`;
    s += `<circle cx="${k * 42 - 9}" cy="24" r="9" fill="${C.ink}"/><circle cx="${k * 42 - 12}" cy="20" r="3" fill="#fff"/>`;
    s += `<path d="M${k * 42 - 20} 54 Q${k * 42} 62 ${k * 42 + 20} 54" fill="none" stroke="${C.skinShade}" stroke-width="5" stroke-linecap="round"/>`;
  }
  // nose
  s += `<path d="M-6 30 Q-18 62 0 66 Q16 66 14 56" fill="${C.skinShade}" stroke="${C.ink}" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"/>`;
  // gritted teeth
  s += `<rect x="-42" y="76" width="84" height="32" rx="12" fill="#fff" stroke="${C.ink}" stroke-width="5"/>`;
  s += `<path d="M-40 92 H40 M-21 78 V106 M0 78 V106 M21 78 V106" stroke="${C.ink}" stroke-width="3.5"/>`;
  // sweat running down the face
  s += `<path d="M-88 -20 Q-92 10 -86 40" fill="none" stroke="${C.sweat}" stroke-width="7" stroke-linecap="round"/>`;
  s += drop(-86, 46, 0.7);
  s += `<path d="M90 -18 Q94 6 88 28" fill="none" stroke="${C.sweat}" stroke-width="7" stroke-linecap="round"/>`;
  s += drop(88, 34, 0.6);
  s += drop(-30, -10, 0.55) + drop(36, -14, 0.5);
  // drops flying off
  s += drop(-150, -70, 1.1, -40) + drop(-175, 5, 0.9, -70) + drop(-140, -135, 0.8, -25);
  s += drop(150, -70, 1.1, 40) + drop(178, 5, 0.9, 70) + drop(140, -138, 0.8, 25);
  s += drop(-55, -170, 0.75, -10) + drop(60, -172, 0.75, 10);
  // effort/motion lines
  for (const [x1, y1, x2, y2] of [[-200, -110, -235, -135], [-215, -40, -255, -45], [200, -110, 235, -135], [215, -40, 255, -45]])
    s += `<path d="M${x1} ${y1} L${x2} ${y2}" stroke="#fff" stroke-width="8" stroke-linecap="round" opacity=".85"/>`;
  return s + '</g>';
}

// Conveyor belt spanning x0..x1 with its running surface at y.
function conveyor(x0, x1, y, floorY) {
  let s = '';
  for (let x = x0 + 80; x < x1; x += 260)
    s += `<rect x="${x}" y="${y + 100}" width="34" height="${floorY - y - 100}" fill="#4a5568" stroke="${C.ink}" stroke-width="5"/>` +
         `<rect x="${x - 10}" y="${floorY - 14}" width="54" height="14" fill="#2d3748" stroke="${C.ink}" stroke-width="4"/>`;
  s += `<rect x="${x0}" y="${y + 70}" width="${x1 - x0}" height="16" fill="#2d3748"/>`;
  s += `<rect x="${x0}" y="${y - 22}" width="${x1 - x0}" height="40" fill="#25272e" stroke="${C.ink}" stroke-width="5"/>`;
  for (let x = x0 + 10; x < x1; x += 46) s += `<path d="M${x} ${y - 20} L${x - 12} ${y + 16}" stroke="#3b3f4a" stroke-width="5"/>`;
  s += `<rect x="${x0}" y="${y + 14}" width="${x1 - x0}" height="62" rx="6" fill="#9aa5b8" stroke="${C.ink}" stroke-width="6"/>`;
  s += `<rect x="${x0}" y="${y + 20}" width="${x1 - x0}" height="10" fill="#c5cfdd"/>`;
  for (let x = x0 + 40; x < x1; x += 120)
    s += `<circle cx="${x}" cy="${y + 46}" r="17" fill="#5d6778" stroke="${C.ink}" stroke-width="4"/><circle cx="${x}" cy="${y + 46}" r="5" fill="${C.ink}"/>`;
  return s;
}

const speedLines = (x, y, h, n = 3) => {
  let s = '';
  for (let i = 0; i < n; i++) {
    const yy = y - h * (0.2 + 0.3 * i);
    s += `<path d="M${x - 20 - i * 12} ${yy} H${x - 90 - i * 25}" stroke="#fff" stroke-width="6" stroke-linecap="round" opacity=".55"/>`;
  }
  return s;
};

const fontFace = `<style>@font-face{font-family:Bungee;src:url(data:font/ttf;base64,${FONT})}</style>`;

function homeScreen(withTitle) {
  const W = 1080, H = 1920, beltY = 1270, floorY = 1640;
  let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`;
  s += `<defs>${withTitle ? fontFace : ''}
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0e1626"/><stop offset=".55" stop-color="#22324d"/><stop offset="1" stop-color="#2b3a55"/></linearGradient>
    <linearGradient id="floor" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3d4659"/><stop offset="1" stop-color="#1c2230"/></linearGradient>
    <linearGradient id="beam" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe9a8" stop-opacity=".55"/><stop offset="1" stop-color="#ffe9a8" stop-opacity="0"/></linearGradient>
    <radialGradient id="glow" cx=".5" cy=".42" r=".5"><stop offset="0" stop-color="#ffb347" stop-opacity=".45"/><stop offset="1" stop-color="#ffb347" stop-opacity="0"/></radialGradient>
  </defs>`;
  s += `<rect width="${W}" height="${H}" fill="url(#bg)"/>`;
  // ceiling trusses
  for (let x = -40; x < W; x += 180) s += `<path d="M${x} 0 L${x + 90} 110 L${x + 180} 0" fill="none" stroke="#33415c" stroke-width="10"/>`;
  s += `<rect x="0" y="105" width="${W}" height="16" fill="#33415c"/>`;
  // loading dock doors on the back wall
  for (let i = 0; i < 4; i++) {
    const x = 30 + i * 270;
    s += `<rect x="${x}" y="640" width="210" height="440" fill="#141c2b" stroke="#3c4a66" stroke-width="8"/>`;
    for (let y = 660; y < 820; y += 22) s += `<path d="M${x + 6} ${y} H${x + 204}" stroke="#2d3a52" stroke-width="5"/>`;
    s += `<rect x="${x + 70}" y="600" width="70" height="34" rx="4" fill="#ffd166"/><text x="${x + 105}" y="626" font-family="Liberation Sans, sans-serif" font-weight="700" font-size="26" text-anchor="middle" fill="${C.ink}">${12 + i}</text>`;
  }
  // the 4 AM clock
  s += `<circle cx="900" cy="470" r="62" fill="#f4f1e8" stroke="#3c4a66" stroke-width="10"/>`;
  for (let i = 0; i < 12; i++) { const a = i * Math.PI / 6; s += `<path d="M${900 + Math.sin(a) * 48} ${470 - Math.cos(a) * 48} L${900 + Math.sin(a) * 56} ${470 - Math.cos(a) * 56}" stroke="${C.ink}" stroke-width="4"/>`; }
  s += `<path d="M900 470 L${900 + Math.sin(4 * Math.PI / 6) * 30} ${470 - Math.cos(4 * Math.PI / 6) * 30}" stroke="${C.ink}" stroke-width="8" stroke-linecap="round"/><path d="M900 470 V424" stroke="${C.ink}" stroke-width="5" stroke-linecap="round"/><circle cx="900" cy="470" r="6" fill="${C.cap}"/>`;
  // background package stacks
  for (const [x, y, w, h] of [[20, 1130, 140, 110], [40, 1030, 110, 100], [890, 1140, 170, 120], [920, 1040, 120, 100], [180, 1170, 90, 70]])
    s += `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#5b4a3a" stroke="#2a2a35" stroke-width="5" opacity=".75"/>`;
  // hanging lights
  for (const x of [180, 540, 900]) {
    s += `<path d="M${x - 230} 1250 L${x - 40} 230 L${x + 40} 230 L${x + 230} 1250 Z" fill="url(#beam)" opacity=".45"/>`;
    s += `<path d="M${x} 120 V200" stroke="#33415c" stroke-width="6"/><path d="M${x - 50} 232 Q${x} 180 ${x + 50} 232 Z" fill="#4a5568" stroke="${C.ink}" stroke-width="5"/><ellipse cx="${x}" cy="234" rx="38" ry="9" fill="#fff6c9"/>`;
  }
  s += `<ellipse cx="540" cy="900" rx="560" ry="560" fill="url(#glow)"/>`;
  // floor with safety stripe
  s += `<rect x="0" y="${floorY - 200}" width="${W}" height="${H - floorY + 200}" fill="url(#floor)"/>`;
  s += `<path d="M0 ${floorY - 200} H${W}" stroke="#1c2230" stroke-width="6"/>`;
  s += `<rect x="0" y="${floorY + 40}" width="${W}" height="36" fill="#ffd166"/>`;
  for (let x = -40; x < W + 40; x += 70) s += `<path d="M${x} ${floorY + 76} L${x + 36} ${floorY + 40} L${x + 66} ${floorY + 40} L${x + 30} ${floorY + 76} Z" fill="${C.ink}"/>`;
  // the worker (behind the belt)
  s += `<ellipse cx="560" cy="${floorY - 10}" rx="260" ry="40" fill="#000" opacity=".3"/>`;
  s += `<g transform="translate(560 740) scale(1.22)">${worker()}</g>`;
  // conveyor + packages streaming in from the left, piling up on the right
  s += conveyor(-20, W + 20, beltY, floorY);
  s += speedLines(20, beltY - 10, 120) + box(20, beltY - 6, 150, 110, { fragile: true });
  s += speedLines(210, beltY - 10, 80) + box(210, beltY - 6, 110, 80, { rot: -4 });
  s += speedLines(360, beltY - 10, 140) + box(360, beltY - 6, 120, 140, { rot: 3 });
  s += box(790, beltY - 6, 130, 100, { rot: -3 });
  s += box(930, beltY - 6, 120, 120, { rot: 6 });
  s += box(820, beltY - 112, 110, 90, { rot: -9, fragile: true });
  s += box(960, beltY - 128, 90, 80, { rot: 14 });
  s += box(880, beltY - 210, 100, 80, { rot: 22 });
  // a box tumbling off the end
  s += box(990, 1460, 110, 90, { rot: 38, label: false });
  s += `<path d="M960 1360 Q975 1395 990 1400 M1020 1350 Q1040 1385 1060 1390" fill="none" stroke="#fff" stroke-width="6" stroke-linecap="round" opacity=".6"/>`;
  // floor clutter
  s += box(110, 1820, 150, 110, { rot: -8 }) + box(260, 1835, 120, 90, { rot: 10, label: false });
  s += box(760, 1830, 160, 120, { rot: 6, fragile: true });

  if (withTitle) {
    s += `<g transform="rotate(-5 540 300)" font-family="Bungee, Liberation Sans, sans-serif" text-anchor="middle">
      <text x="548" y="352" font-size="168" fill="${C.ink}">PRELOAD</text>
      <text x="540" y="340" font-size="168" fill="${C.vest}" stroke="${C.ink}" stroke-width="14" paint-order="stroke" stroke-linejoin="round">PRELOAD</text>
      <text x="540" y="340" font-size="168" fill="none" stroke="#fff3c4" stroke-width="3" opacity=".7">PRELOAD</text>
    </g>`;
    s += `<g transform="rotate(-5 540 430)"><rect x="300" y="390" width="480" height="78" rx="14" fill="${C.cap}" stroke="${C.ink}" stroke-width="8"/>
      <text x="540" y="447" font-family="Bungee, Liberation Sans, sans-serif" font-size="46" text-anchor="middle" fill="#fff">RUSH HOUR</text></g>`;
    s += `<rect x="290" y="1735" width="500" height="104" rx="52" fill="${C.ink}" opacity=".7"/>`;
    s += `<text x="540" y="1804" font-family="Bungee, Liberation Sans, sans-serif" font-size="48" text-anchor="middle" fill="#fff">TAP TO START</text>`;
  }
  return s + '</svg>';
}

function appIcon() {
  const S = 1024;
  let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">`;
  s += `<defs><radialGradient id="ibg" cx=".5" cy=".4" r=".75"><stop offset="0" stop-color="#ffc24b"/><stop offset=".6" stop-color="#ff8a1f"/><stop offset="1" stop-color="#d9480f"/></radialGradient></defs>`;
  s += `<rect width="${S}" height="${S}" fill="url(#ibg)"/>`;
  // sunburst
  for (let i = 0; i < 16; i++) {
    const a = (i / 16) * Math.PI * 2, b = a + Math.PI / 16;
    s += `<path d="M512 420 L${512 + Math.cos(a) * 1000} ${420 + Math.sin(a) * 1000} L${512 + Math.cos(b) * 1000} ${420 + Math.sin(b) * 1000} Z" fill="#fff" opacity=".09"/>`;
  }
  s += `<g transform="translate(512 330) scale(1.55)">${worker()}</g>`;
  s += `<rect x="0" y="940" width="${S}" height="${S - 940}" fill="#2d3748"/>`;
  s += conveyor(-20, S + 20, 880, 1100);
  s += speedLines(60, 872, 110) + box(40, 874, 150, 110, { fragile: true });
  s += box(800, 874, 170, 120, { rot: 5 });
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
    await page.screenshot({ path: path.join(OUT, file), omitBackground: false });
  };
  await render(files['home_screen.svg'], 1080, 1920, 'home_screen.png');
  await render(files['home_screen_titled.svg'], 1080, 1920, 'home_screen_titled.png');
  for (const size of [1024, 512, 192, 180, 120])
    await render(files['app_icon.svg'], size, size, size === 1024 ? 'app_icon.png' : `app_icon_${size}.png`);
  await browser.close();
})();
