// Generates the iOS / Android launcher icons and the store icon from the
// SVG design below. Requires Node, Playwright (Chromium) and ImageMagick.
//
//   node branding/app-icon/generate.mjs
//
// Run from the repository root. Outputs are committed, so this only needs
// to be re-run when the design changes.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_PATH ?? 'playwright');

const root = process.cwd();
const out = (p) => path.join(root, p);

// --- Design (1024x1024 user space) ------------------------------------------

const bgTop = '#1F2630';
const bgBottom = '#0B0E11';

const defs = `<defs>
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${bgTop}"/><stop offset="1" stop-color="${bgBottom}"/></linearGradient>
<linearGradient id="ai" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#7CC4FF"/><stop offset="1" stop-color="#B69CFF"/></linearGradient>
<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="18" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
</defs>`;

// Four-point sparkle centred on (cx, cy).
function sparklePath(cx, cy, r) {
  const k = r * 0.16;
  return `M${cx} ${cy - r}C${cx + k} ${cy - k} ${cx + k} ${cy - k} ${cx + r} ${cy}` +
    `C${cx + k} ${cy + k} ${cx + k} ${cy + k} ${cx} ${cy + r}` +
    `C${cx - k} ${cy + k} ${cx - k} ${cy + k} ${cx - r} ${cy}` +
    `C${cx - k} ${cy - k} ${cx - k} ${cy - k} ${cx} ${cy - r}Z`;
}

const chevron = 'M280 350L460 512L280 674';
const chevronWidth = 92;
// Cursor: 210x88 pill at (540, 630).
const cursor = 'M584 630H706A44 44 0 0 1 706 718H584A44 44 0 0 1 584 630Z';
const bigSparkle = sparklePath(730, 330, 110);
const smallSparkle = sparklePath(620, 250, 44);

function glyph({ mono = false } = {}) {
  const c = (color) => (mono ? '#FFFFFF' : color);
  return `<path d="${chevron}" fill="none" stroke="${c('url(#ai)')}" stroke-width="${chevronWidth}" stroke-linecap="round" stroke-linejoin="round"/>
<path d="${cursor}" fill="${c('#5EEAD4')}"/>
<path d="${bigSparkle}" fill="${c('#F5C46B')}"${mono ? '' : ' filter="url(#glow)"'}/>
<path d="${smallSparkle}" fill="${c('#E6E9EE')}"/>`;
}

const svg = (body) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">${defs}${body}</svg>`;

// Adaptive icon layers are 108dp with only the centre ~72dp visible, so the
// glyph is scaled down to sit inside the safe zone.
const adaptiveScale = 0.7;
const scaled = (body) =>
  `<g transform="translate(512 512) scale(${adaptiveScale}) translate(-512 -512)">${body}</g>`;

const designs = {
  full: svg(`<rect width="1024" height="1024" fill="url(#bg)"/>${glyph()}`),
  foreground: svg(scaled(glyph())),
  monochrome: svg(scaled(glyph({ mono: true }))),
  // Legacy (pre-API 26) launcher icon: rounded square on transparent.
  legacy: svg(`<rect x="40" y="40" width="944" height="944" rx="200" fill="url(#bg)"/>${glyph()}`),
};

// --- Rendering ---------------------------------------------------------------

const browser = await chromium.launch();
const page = await browser.newPage();

async function render(design, size, file, { opaque = false } = {}) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  await page.setViewportSize({ width: size, height: size });
  await page.setContent(
    `<html><body style="margin:0">${design.replace('<svg ', `<svg width="${size}" height="${size}" `)}</body></html>`,
  );
  await page.screenshot({ path: file, omitBackground: !opaque });
  // App Store rejects icons with an alpha channel.
  if (opaque) execFileSync('convert', [file, '-alpha', 'off', '-strip', file]);
  else execFileSync('convert', [file, '-strip', file]);
}

// iOS: every entry in AppIcon.appiconset/Contents.json.
const iosDir = out('ios/Runner/Assets.xcassets/AppIcon.appiconset');
const contents = JSON.parse(fs.readFileSync(path.join(iosDir, 'Contents.json'), 'utf8'));
const done = new Set();
for (const image of contents.images) {
  if (!image.filename || done.has(image.filename)) continue;
  done.add(image.filename);
  const pt = parseFloat(image.size);
  const px = Math.round(pt * parseInt(image.scale));
  await render(designs.full, px, path.join(iosDir, image.filename), { opaque: true });
}

// Android.
const res = out('android/app/src/main/res');
const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
for (const [name, factor] of Object.entries(densities)) {
  const dir = path.join(res, `mipmap-${name}`);
  await render(designs.legacy, 48 * factor, path.join(dir, 'ic_launcher.png'));
  await render(designs.foreground, 108 * factor, path.join(dir, 'ic_launcher_foreground.png'));
  await render(designs.monochrome, 108 * factor, path.join(dir, 'ic_launcher_monochrome.png'));
}

// Store listing icons.
await render(designs.full, 512, out('branding/app-icon/play-store-512.png'), { opaque: true });
await render(designs.full, 1024, out('branding/app-icon/app-store-1024.png'), { opaque: true });
fs.writeFileSync(out('branding/app-icon/icon.svg'), designs.full + '\n');

await browser.close();

// Notification small icon (white silhouette, Android vector drawable). The
// viewport is cropped around the glyph so it fills the 24dp icon.
const vb = { x: 200, y: 180, size: 680 };
const notification = `<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by branding/app-icon/generate.mjs -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="${vb.size}"
    android:viewportHeight="${vb.size}">
    <group android:translateX="${-vb.x}" android:translateY="${-vb.y}">
        <path
            android:pathData="${chevron}"
            android:strokeColor="#FFFFFFFF"
            android:strokeWidth="${chevronWidth}"
            android:strokeLineCap="round"
            android:strokeLineJoin="round" />
        <path android:fillColor="#FFFFFFFF" android:pathData="${cursor}" />
        <path android:fillColor="#FFFFFFFF" android:pathData="${bigSparkle}" />
        <path android:fillColor="#FFFFFFFF" android:pathData="${smallSparkle}" />
    </group>
</vector>
`;
fs.writeFileSync(path.join(res, 'drawable/ic_notification.xml'), notification);
