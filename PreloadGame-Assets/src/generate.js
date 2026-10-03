// Generates the Preload game home screen and app icon as SVG + PNG.
// Style: low-poly 64-bit-console worker over a flat editorial backdrop — soft blue
// with pale blobs and a film-grain overlay.
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

// ---- Low-poly "64-bit console" worker -------------------------------------
// Built from flat-shaded polygons lit from the upper left, with a low-res pixel
// face texture softened by a slight blur (like old bilinear texture filtering).

const shade = (hex, f) => {
  const n = parseInt(hex.slice(1), 16);
  const c = [n >> 16, (n >> 8) & 255, n & 255].map(v => Math.max(0, Math.min(255, Math.round(f >= 1 ? v + (255 - v) * (f - 1) : v * f))));
  return '#' + c.map(v => v.toString(16).padStart(2, '0')).join('');
};
const poly = (pts, fill) => `<polygon points="${pts.map(p => p.join(',')).join(' ')}" fill="${fill}"/>`;

// A limb segment drawn as a three-faced prism from p1 to p2.
function prism([x1, y1], [x2, y2], w1, base, w2 = w1) {
  const len = Math.hypot(x2 - x1, y2 - y1), nx = -(y2 - y1) / len, ny = (x2 - x1) / len;
  const at = (x, y, w, k) => [x + nx * w * k, y + ny * w * k];
  const ks = [0.5, 0.17, -0.17, -0.5];
  // the side whose normal points left/up catches the light
  const lightFirst = nx + ny * 0.5 < 0;
  const tones = lightFirst ? [1.22, 1.0, 0.74] : [0.74, 1.0, 1.22];
  let s = '';
  for (let i = 0; i < 3; i++)
    s += poly([at(x1, y1, w1, ks[i]), at(x2, y2, w2, ks[i]), at(x2, y2, w2, ks[i + 1]), at(x1, y1, w1, ks[i + 1])], shade(base, tones[i]));
  return s;
}

// Hexagonal joint cap to hide seams between prisms.
function joint([x, y], r, base) {
  const p = a => [x + Math.cos(a) * r, y + Math.sin(a) * r];
  const pts = [0, 1, 2, 3, 4, 5].map(i => p(Math.PI / 6 + i * Math.PI / 3));
  return poly([pts[2], pts[3], pts[4], [x, y]], shade(base, 1.22)) + poly([pts[4], pts[5], pts[0], [x, y]], shade(base, 1.0)) +
         poly([pts[0], pts[1], pts[2], [x, y]], shade(base, 0.74));
}

// Chunky open hand, fingers pointing up in local space.
function blockHand(x, y, angle, base) {
  let s = `<g transform="translate(${x} ${y}) rotate(${angle})">`;
  s += poly([[-26, 4], [-30, -36], [-20, -52], [0, -54], [0, 4]], shade(base, 1.18));
  s += poly([[0, 4], [0, -54], [20, -52], [30, -36], [26, 4]], shade(base, 0.9));
  for (const [fx, top] of [[-21, -92], [-8, -100], [5, -98], [18, -88]]) {
    s += poly([[fx - 6, -50], [fx - 6, top + 6], [fx, top], [fx, -50]], shade(base, 1.15));
    s += poly([[fx, -50], [fx, top], [fx + 6, top + 6], [fx + 6, -50]], shade(base, 0.82));
  }
  s += poly([[-26, -12], [-50, -38], [-44, -48], [-22, -30]], shade(base, 1.05));
  s += poly([[-22, -30], [-44, -48], [-36, -50], [-18, -38]], shade(base, 0.8));
  return s + '</g>';
}

// Low-poly sweat drop (a diamond with a lit and a shaded half).
const polyDrop = (x, y, s = 1, r = 0) =>
  `<g transform="translate(${x} ${y}) rotate(${r}) scale(${s})">` +
  poly([[0, -24], [0, 18], [-13, 4]], '#ffffff') + poly([[0, -24], [13, 4], [0, 18]], C.sweatBlue) + '</g>';

// 16 x 14 face texture, 10 px per texel, centered on the face.
const FACE = [
  '................',
  '..bbbb..........',
  '.b....b..bbbbbb.',
  '................',
  '..wwww....wwww..',
  '..wppw....wppw..',
  '..ssss....ssss..',
  '.......nn.......',
  '.rr...nnnn...rr.',
  '...mmmmmmmmmm...',
  '..mmm......mmm..',
  '.....kkkkkk.....',
  '....kttttttk....',
  '...k........k...',
];
function faceTexture(x0, y0, px) {
  const pal = { b: C.hair, w: C.tee, p: C.hair, s: shade(C.skin, 0.78), n: shade(C.skin, 0.72), r: C.flush, m: C.hair, k: C.mouth, t: C.tee };
  let s = `<g filter="url(#texfilter)">`;
  FACE.forEach((row, j) => [...row].forEach((ch, i) => {
    if (pal[ch]) s += `<rect x="${x0 + i * px}" y="${y0 + j * px}" width="${px + 0.5}" height="${px + 0.5}" fill="${pal[ch]}"${ch === 'r' ? ' opacity=".55"' : ''}/>`;
  }));
  return s + '</g>';
}

// The worker, facing the player with both hands thrown up. Origin = base of the neck.
function worker() {
  const sk = C.skin, sh = C.shirt, pa = C.pants;
  let s = '<g>';
  // legs and boots
  s += prism([-55, 360], [-62, 740], 78, pa, 70) + prism([55, 360], [62, 740], 78, pa, 70);
  for (const k of [-1, 1]) {
    const x = k * 62;
    s += poly([[x - 40, 730], [x + 40, 730], [x + 44, 760], [x - 44, 760]], shade(C.boot, 1.4));
    s += poly([[x - 44, 760], [x + 44, 760], [x + 50, 784], [x - 56, 784]], shade(C.boot, 1.0));
  }
  // arms (behind the torso at the shoulder)
  const arms = [
    { sh: [-112, 46], el: [-232, -46], wr: [-262, -196], ang: -14 },
    { sh: [112, 46], el: [232, -46], wr: [256, -196], ang: 14 },
  ];
  for (const a of arms) {
    const mid = [a.sh[0] + (a.el[0] - a.sh[0]) * 0.55, a.sh[1] + (a.el[1] - a.sh[1]) * 0.55];
    s += prism(mid, a.el, 46, sk, 42) + joint(a.el, 22, sk) + prism(a.el, a.wr, 42, sk, 36);
    s += prism(a.sh, mid, 74, sh, 66);
    s += blockHand(a.wr[0], a.wr[1] + 6, a.ang, sk);
  }
  // torso: faceted chest and belly, lit from the left
  const P = { ls: [-128, 24], rs: [128, 24], ln: [-38, 0], rn: [38, 0], c0: [0, 8], lm: [-134, 200], rm: [134, 200], c1: [0, 200], lw: [-104, 380], rw: [104, 380], c2: [0, 380] };
  s += poly([P.ls, P.ln, P.c0, P.lm], shade(sh, 1.25)) + poly([P.c0, P.c1, P.lm], shade(sh, 1.08));
  s += poly([P.lm, P.c1, P.lw], shade(sh, 1.0)) + poly([P.c1, P.c2, P.lw], shade(sh, 0.9));
  s += poly([P.rs, P.rn, P.c0, P.rm], shade(sh, 0.95)) + poly([P.c0, P.c1, P.rm], shade(sh, 0.82));
  s += poly([P.rm, P.c1, P.rw], shade(sh, 0.74)) + poly([P.c1, P.c2, P.rw], shade(sh, 0.68));
  s += poly([[-104, 330], [104, 330], [104, 350], [-104, 350]], shade(sh, 0.6));
  s += poly([[96, 70], [128, 90], [124, 150], [96, 140]], C.sweatPatch);
  // collar, undershirt, buttons
  s += poly([[-30, 0], [30, 0], [0, 56]], C.tee);
  s += poly([[-52, -6], [-4, 54], [-24, 70], [-66, 14]], shade(sh, 1.4)) + poly([[52, -6], [4, 54], [24, 70], [66, 14]], shade(sh, 1.1));
  s += poly([[-6, 88], [6, 88], [6, 100], [-6, 100]], C.button) + poly([[-6, 120], [6, 120], [6, 132], [-6, 132]], C.button);
  // neck
  s += prism([0, -70], [0, 8], 58, sk);
  // head: chamfered block, faceted
  const H = { a: [-58, -272], b: [58, -272], m1: [0, -276], c: [-84, -230], d: [84, -230], e: [-86, -150], f: [86, -150], m2: [0, -150], g: [-62, -80], h: [62, -80], i: [-24, -50], j: [24, -50] };
  s += poly([[-84, -170], [-102, -160], [-100, -126], [-84, -120]], shade(sk, 1.1)) + poly([[84, -170], [102, -160], [100, -126], [84, -120]], shade(sk, 0.7));
  s += poly([H.a, H.m1, H.m2, H.e, H.c], shade(sk, 1.2)) + poly([H.b, H.m1, H.m2, H.f, H.d], shade(sk, 0.95));
  s += poly([H.e, H.m2, [0, -52], H.i, H.g], shade(sk, 1.06)) + poly([H.f, H.m2, [0, -52], H.j, H.h], shade(sk, 0.8));
  s += poly([H.g, H.i, [-14, -44], [-50, -70]], shade(sk, 0.85)) + poly([H.h, H.j, [14, -44], [50, -70]], shade(sk, 0.62));
  s += poly([H.i, H.j, [14, -44], [-14, -44]], shade(sk, 0.72));
  // face texture, then a faceted nose on top
  s += faceTexture(-80, -212, 10);
  s += poly([[0, -152], [-14, -128], [0, -122]], shade(sk, 1.15)) + poly([[0, -152], [0, -122], [14, -128]], shade(sk, 0.75));
  // cap: faceted dome, bill and button
  s += poly([[-84, -224], [-70, -282], [-30, -302], [0, -304], [0, -226]], shade(C.cap, 1.25));
  s += poly([[84, -224], [70, -282], [30, -302], [0, -304], [0, -226]], shade(C.cap, 0.9));
  s += poly([[-30, -302], [0, -304], [30, -302], [0, -290]], shade(C.cap, 1.45));
  s += poly([[-104, -230], [0, -246], [0, -214], [-96, -206]], shade(C.cap, 1.1)) + poly([[104, -230], [0, -246], [0, -214], [96, -206]], shade(C.cap, 0.85));
  s += poly([[-96, -206], [0, -214], [96, -206], [86, -198], [-86, -198]], shade(C.cap, 0.55));
  s += poly([[-8, -304], [8, -304], [8, -316], [-8, -316]], shade(C.cap, 0.75)) + poly([[-8, -316], [8, -316], [4, -320], [-4, -320]], shade(C.cap, 1.3));
  // sweat: a blocky trickle and drops
  s += poly([[60, -196], [68, -196], [70, -126], [62, -126]], C.sweatBlue);
  s += polyDrop(66, -116, 0.5) + polyDrop(-64, -186, 0.4) + polyDrop(-58, -132, 0.38) + polyDrop(4, -200, 0.36);
  s += polyDrop(-150, -300, 0.9, -30) + polyDrop(-175, -200, 0.8, -60) + polyDrop(-90, -370, 0.75, -15);
  s += polyDrop(120, -300, 0.9, 30) + polyDrop(140, -200, 0.75, 60) + polyDrop(30, -390, 0.7, 10);
  // frustration marks
  for (const [x1, y1, x2, y2] of [[-330, -270, -360, -300], [-345, -215, -385, -222], [290, -280, 318, -312], [305, -225, 345, -232]])
    s += `<path d="M${x1} ${y1} L${x2} ${y2}" stroke="#ffffff" stroke-width="9" stroke-linecap="square" opacity=".75"/>`;
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
  <filter id="texfilter"><feGaussianBlur stdDeviation=".9"/></filter>
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
