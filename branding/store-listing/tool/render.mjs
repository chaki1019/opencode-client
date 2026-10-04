// Composes store screenshots and the Play feature graphic from raw app
// shots taken by store_screenshots_test.dart. Run from the repository root:
//
//   NOTO_JP_DIR=<dir with NotoSansJP-{400,600,700}.ttf> \
//     node branding/store-listing/tool/render.mjs <shots dir> branding/store-listing
//
// Requires Node and Playwright (Chromium). Set PLAYWRIGHT_PATH when
// Playwright is not resolvable from here, and CHROMIUM_PATH to use a
// specific browser binary.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_PATH ?? 'playwright');

const [shots, out, icon = 'branding/app-icon/app-store-1024.png'] =
  process.argv.slice(2);
const fonts = process.env.NOTO_JP_DIR ?? 'fonts';
const plex = 'assets/fonts';
const url = (p) => 'file://' + path.resolve(p);

const copy = {
  ja: {
    chat: ['席を離れても、', 'エージェントに指示', 'PC の OpenCode をスマホから操作'],
    permission: ['許可や質問に、', 'その場で回答', '確認待ちで作業が止まらない'],
    notify: ['終わったら、', '通知でお知らせ', '完了・エラー・許可待ちを通知'],
    diff: ['変更を', 'スマホでレビュー', 'Git の差分をその場で確認'],
    model: ['モデルもエージェントも、', 'すぐ切り替え', 'サーバーで使えるモデルから選択'],
    connect: ['同じネットワークの', 'サーバーを自動で検出', 'アドレスを打たずにすぐ接続'],
    note: {
      title: 'todo-app: 応答が完了しました',
      body: 'ログインの入力チェックを修正',
      now: '今',
    },
    feature: ['自分の OpenCode を、', 'ポケットに。'],
    unofficial: 'OpenCode 非公式クライアント',
  },
  en: {
    chat: ['Keep your agent', 'working from anywhere', 'Drive OpenCode on your computer from your phone'],
    permission: ['Approve requests', 'on the spot', 'Never leave your agent waiting'],
    notify: ['Get notified', "when it's done", 'Replies, errors and permission requests'],
    diff: ['Review changes', 'on the go', 'Git diffs right on your phone'],
    model: ['Switch models', 'in a tap', "Pick from your server's models and agents"],
    connect: ['Finds servers', 'on your network', 'Connect without typing an address'],
    note: {
      title: 'todo-app: Reply finished',
      body: 'Fix login form validation',
      now: 'now',
    },
    feature: ['Your OpenCode,', 'in your pocket.'],
    unofficial: 'Unofficial OpenCode client',
  },
};

const phoneOrder = [
  ['chat', 'chat'],
  ['permission', 'permission'],
  ['notify', 'sessions'],
  ['diff', 'diff'],
  ['model', 'model'],
  ['connect', 'connect'],
];
const tabletOrder = [
  ['chat', 'chat'],
  ['permission', 'permission'],
  ['notify', 'chat'],
  ['diff', 'diff'],
  ['model', 'model'],
];

const css = `
@font-face { font-family: Plex; src: url(${url(plex + '/IBMPlexSans-Bold.ttf')}); font-weight: 700; }
@font-face { font-family: Plex; src: url(${url(plex + '/IBMPlexSans-SemiBold.ttf')}); font-weight: 600; }
@font-face { font-family: Plex; src: url(${url(plex + '/IBMPlexSans-Regular.ttf')}); font-weight: 400; }
@font-face { font-family: NotoJP; src: url(${url(fonts + '/NotoSansJP-700.ttf')}); font-weight: 700; }
@font-face { font-family: NotoJP; src: url(${url(fonts + '/NotoSansJP-600.ttf')}); font-weight: 600; }
@font-face { font-family: NotoJP; src: url(${url(fonts + '/NotoSansJP-400.ttf')}); font-weight: 400; }
* { margin: 0; box-sizing: border-box; }
html, body { width: 100%; height: 100%; }
body {
  font-family: Plex, NotoJP, sans-serif; color: #E6E9EE; overflow: hidden;
  background:
    radial-gradient(ellipse 80% 45% at 50% 0%, rgba(124,196,255,.20), transparent 70%),
    radial-gradient(ellipse 60% 40% at 100% 100%, rgba(182,156,255,.14), transparent 70%),
    linear-gradient(180deg, #1A2029 0%, #0B0E11 100%);
  display: flex; flex-direction: column; align-items: center;
}
.cap { text-align: center; padding-top: var(--top); }
.cap h1 { font-weight: 700; font-size: var(--h1); line-height: 1.22; letter-spacing: -0.01em; }
.cap h1 .ai { background: linear-gradient(90deg, #7CC4FF, #B69CFF); -webkit-background-clip: text; color: transparent; }
.cap p { margin-top: calc(var(--h1) * .32); font-size: calc(var(--h1) * .40); color: #9AA4B2; font-weight: 400; }
.dev {
  position: relative; margin-top: var(--gap); width: var(--dw);
  border-radius: var(--r); padding: var(--bz); background: #05070A;
  box-shadow: 0 0 0 calc(var(--bz) * .22) #2A323D, 0 40px 120px rgba(0,0,0,.6), 0 0 160px rgba(124,196,255,.10);
}
.dev .scr { position: relative; border-radius: calc(var(--r) - var(--bz)); overflow: hidden; }
.dev img.shot { display: block; width: 100%; }
.sb { position: absolute; left: 0; right: 0; top: 0; height: var(--sbh); display: flex; align-items: center;
  justify-content: space-between; padding: 0 var(--sbp); font-weight: 600; font-size: var(--sbf); color: #E6E9EE; }
.sb .ic { display: flex; gap: calc(var(--sbf) * .35); align-items: center; }
.island { position: absolute; top: calc(var(--sbh) * .2); left: 50%; transform: translateX(-50%);
  width: 29%; height: calc(var(--sbh) * .6); background: #000; border-radius: 999px; }
.note { position: absolute; left: 3.5%; right: 3.5%; top: calc(var(--sbh) + 1%); border-radius: var(--nr);
  background: rgba(46,52,62,.86); backdrop-filter: blur(20px); padding: var(--np); display: flex; gap: var(--np);
  align-items: center; box-shadow: 0 20px 60px rgba(0,0,0,.5); border: 1px solid rgba(255,255,255,.08); }
.note img { width: var(--ni); height: var(--ni); border-radius: 22%; }
.note .t { flex: 1; min-width: 0; }
.note .row { display: flex; justify-content: space-between; font-size: var(--nf); }
.note b { font-weight: 600; }
.note .when { color: #9AA4B2; }
.note .body { font-size: var(--nf); color: #C9CFD8; margin-top: .2em; }
.dim::after { content: ''; position: absolute; inset: 0; background: rgba(0,0,0,.35); }
`;

const battery = (f) => `<svg width="${f * 1.6}" height="${f * 0.8}" viewBox="0 0 26 13"><rect x=".5" y=".5" width="22" height="12" rx="3.5" fill="none" stroke="#E6E9EE" opacity=".5"/><rect x="2" y="2" width="17" height="9" rx="2" fill="#E6E9EE"/><rect x="24" y="4.5" width="1.5" height="4" rx=".75" fill="#E6E9EE" opacity=".5"/></svg>`;
const signal = (f) => `<svg width="${f * 1.1}" height="${f * 0.75}" viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1" fill="#E6E9EE"/><rect x="5" y="5.5" width="3" height="6.5" rx="1" fill="#E6E9EE"/><rect x="10" y="3" width="3" height="9" rx="1" fill="#E6E9EE"/><rect x="15" y="0" width="3" height="12" rx="1" fill="#E6E9EE"/></svg>`;
const wifi = (f) => `<svg width="${f * 1.05}" height="${f * 0.75}" viewBox="0 0 17 12"><path d="M8.5 2.2c2.6 0 5 1 6.8 2.7l1.2-1.2C14.4 1.6 11.6.5 8.5.5S2.6 1.6.5 3.7l1.2 1.2C3.5 3.2 5.9 2.2 8.5 2.2zm0 3.4c1.7 0 3.2.6 4.4 1.7l1.2-1.2C12.6 4.7 10.6 3.9 8.5 3.9S4.4 4.7 2.9 6.1l1.2 1.2c1.2-1.1 2.7-1.7 4.4-1.7zm0 3.4c.8 0 1.5.3 2 .8L8.5 11.8 6.5 9.8c.5-.5 1.2-.8 2-.8z" fill="#E6E9EE"/></svg>`;

function page({ W, H, kind, lang, key, shot, tablet }) {
  const c = copy[lang];
  const [l1, l2, sub] = c[key];
  // Layout scales with the canvas width; the device shrinks to fit height.
  const u = W / 100;
  const h1 = tablet ? 4.6 * u : 7.4 * u;
  const top = tablet ? 6 * u : 9 * u;
  const capH = top + h1 * 1.22 * 2 + h1 * 0.32 + h1 * 0.4 * 1.5;
  const gap = tablet ? 4 * u : 6 * u;
  const img = shot;
  const ratio = img.h / img.w;
  const bzRel = tablet ? 0.022 : 0.035;
  // Device width so the frame's bottom bleeds a little off the canvas.
  let dw = tablet ? W * 0.84 : W * 0.80;
  const bleed = tablet ? 0.10 : 0.12;
  const maxH = (H - capH - gap) / (1 - bleed);
  if (dw * (1 - 2 * bzRel) * ratio + 2 * bzRel * dw > maxH) {
    dw = maxH / ((1 - 2 * bzRel) * ratio + 2 * bzRel);
  }
  const bz = dw * bzRel;
  const sw = dw - 2 * bz; // screen width in px
  const pt = sw / img.logicalW; // px per app logical pixel
  const sbh = img.top * pt;
  const vars = {
    '--top': top + 'px', '--h1': h1 + 'px', '--gap': gap + 'px', '--dw': dw + 'px',
    '--bz': bz + 'px', '--r': (tablet ? 0.045 : 0.15) * dw + 'px',
    '--sbh': sbh + 'px', '--sbp': (tablet ? 22 : 34) * pt + 'px', '--sbf': (tablet ? 13 : 17) * pt + 'px',
    '--nr': 24 * pt + 'px', '--np': 14 * pt + 'px', '--ni': 38 * pt + 'px', '--nf': 15 * pt + 'px',
  };
  const style = Object.entries(vars).map(([k, v]) => `${k}:${v}`).join(';');
  const f = (tablet ? 13 : 17) * pt;
  const note = key === 'notify'
    ? `<div class="note"><img src="${url(icon)}"><div class="t"><div class="row"><b>${c.note.title}</b><span class="when">${c.note.now}</span></div><div class="body">${c.note.body}</div></div></div>`
    : '';
  return `<!doctype html><html><head><meta charset="utf-8"><style>${css}</style></head>
<body style="${style}">
<div class="cap"><h1>${l1}<br><span class="ai">${l2}</span></h1><p>${sub}</p></div>
<div class="dev"><div class="scr ${key === 'notify' ? 'dim' : ''}"><img class="shot" src="${url(img.file)}">
${kind === 'ios' && !tablet ? '<div class="island"></div>' : ''}
<div class="sb"><span>9:41</span><span class="ic">${signal(f)}${wifi(f)}${battery(f)}</span></div>
</div>${note}</div>
</body></html>`;
}

function featurePage(lang, phoneShot) {
  const c = copy[lang];
  return `<!doctype html><html><head><meta charset="utf-8"><style>${css}
body { flex-direction: row; align-items: center; padding-left: 64px; }
.l { flex: 1; display: flex; flex-direction: column; gap: 18px; position: relative; z-index: 1; }
.brand { display: flex; align-items: center; gap: 18px; }
.brand img { width: 84px; height: 84px; border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,.5); }
.brand span { font-weight: 700; font-size: 40px; }
.tag { font-weight: 700; font-size: 44px; line-height: 1.2; }
.tag .ai { background: linear-gradient(90deg, #7CC4FF, #B69CFF); -webkit-background-clip: text; color: transparent; }
.small { font-size: 17px; color: #9AA4B2; }
.p { position: absolute; right: 40px; top: 46px; width: 300px; transform: rotate(-8deg);
  border-radius: 44px; padding: 10px; background: #05070A;
  box-shadow: 0 0 0 3px #2A323D, 0 30px 80px rgba(0,0,0,.6), 0 0 120px rgba(124,196,255,.18); }
.p img { display: block; width: 100%; border-radius: 34px; }
</style></head><body>
<div class="l"><div class="brand"><img src="${url(icon)}"><span>OpenCode Mobile</span></div>
<div class="tag">${c.feature[0]}<br><span class="ai">${c.feature[1]}</span></div>
<div class="small">${c.unofficial}</div></div>
<div class="p"><img src="${url(phoneShot)}"></div>
</body></html>`;
}

const browser = await chromium.launch(
  process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {},
);
const ctx = await browser.newContext({ deviceScaleFactor: 1 });
const tmp = path.join(out, '.tmp.html');

async function render(html, W, H, file) {
  fs.writeFileSync(tmp, html);
  const p = await ctx.newPage();
  await p.setViewportSize({ width: W, height: H });
  await p.goto(url(tmp));
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(150);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  await p.screenshot({ path: file, type: 'png' });
  await p.close();
  console.log(file);
}

// Store locale folders for each app language.
const locales = {
  ja: { appStore: 'ja', play: 'ja-JP' },
  en: { appStore: 'en-US', play: 'en-US' },
};
const targets = [
  // [store, screenshot folder, kind, W, H, device, order]
  ['app-store', 'iphone-6.9', 'ios', 1290, 2796, 'phone', phoneOrder],
  ['app-store', 'ipad-13', 'ios', 2064, 2752, 'tablet', tabletOrder],
  ['google-play', 'phone', 'android', 1080, 1920, 'phone', phoneOrder],
  ['google-play', 'tablet', 'android', 1600, 2560, 'tablet', tabletOrder],
];
const meta = {
  phone: { logicalW: 430, top: 59 },
  tablet: { logicalW: 1032, top: 24 },
};

for (const lang of ['ja', 'en']) {
  for (const [store, folder, kind, W, H, dev, order] of targets) {
    const locale = store === 'app-store' ? locales[lang].appStore : locales[lang].play;
    for (const [i, [key, shotName]] of order.entries()) {
      const file = `${shots}/${lang}/${dev}-${shotName}.png`;
      const isTablet = dev === 'tablet';
      const shot = { file, w: isTablet ? 2064 : 1290, h: isTablet ? 2752 : 2796, ...meta[dev] };
      const html = page({ W, H, kind, lang, key, shot, tablet: isTablet });
      await render(html, W, H, `${out}/${store}/${locale}/screenshots/${folder}/${i + 1}-${key}.png`);
    }
  }
  await render(featurePage(lang, `${shots}/${lang}/phone-chat.png`), 1024, 500,
    `${out}/google-play/${locales[lang].play}/feature-graphic.png`);
}
fs.rmSync(tmp);
await browser.close();
