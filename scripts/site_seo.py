#!/usr/bin/env python3
"""Writes the search and link-preview tags into every page under site/,
and site/sitemap.xml.

Each page's `<title>` and `<meta name="description">` are the source: the
block between `<!-- seo -->` and `<!-- /seo -->` (canonical URL, hreflang,
Open Graph, X card and, on the landing pages, structured data) is made
from them. The block also loads site/analytics.js (Microsoft Clarity).
Run it from the repository root after adding a page or changing
a title or description:

    python3 scripts/site_seo.py

Pages are listed in PAGES (keep it in step with scripts/site_nav.py);
languages are the folders under site/ that hold an index.html.
"""
import html
import json
import pathlib
import re

SITE = pathlib.Path(__file__).resolve().parent.parent / 'site'
ORIGIN = 'https://opencodemobile.app'
PAGES = ['', 'connect/', 'support/', 'privacy/']
LOCALE = {'ja': 'ja_JP', 'en': 'en_US'}
CURRENCY = {'ja': 'JPY', 'en': 'USD'}
APP_STORE = 'https://apps.apple.com/app/id6818950202'
GOOGLE_PLAY = 'https://play.google.com/store/apps/details?id=app.opencodemobile'
# Link previews use the store feature graphic of the page's language.
IMAGE = ('/img/og-{lang}.jpg', 1024, 500)

TITLE = re.compile(r'<title>(.*?)</title>', re.S)
DESC = re.compile(r'<meta name="description" content="([^"]*)">')
BLOCK = re.compile(r'\n<!-- seo -->\n.*?<!-- /seo -->', re.S)
HREFLANG = re.compile(r'\n<link rel="alternate" hreflang="[^"]+" href="[^"]+">')


def languages():
    return sorted(p.name for p in SITE.iterdir()
                  if p.is_dir() and (p / 'index.html').exists() and p.name != 'img')


def ld(data):
    text = json.dumps(data, ensure_ascii=False, indent=1)
    return '<script type="application/ld+json">\n' + text.replace('</', '<\\/') + '\n</script>'


def website():
    return {'@type': 'WebSite', '@id': f'{ORIGIN}/#website', 'name': 'Pocket Agent', 'url': f'{ORIGIN}/'}


def app(lang, description):
    return {
        '@type': 'MobileApplication',
        'name': 'Pocket Agent',
        'description': description,
        'url': f'{ORIGIN}/{lang}/',
        'image': f'{ORIGIN}/apple-touch-icon.png',
        'inLanguage': lang,
        'operatingSystem': 'iOS, Android',
        'applicationCategory': 'DeveloperApplication',
        'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': CURRENCY[lang]},
        'downloadUrl': [APP_STORE, GOOGLE_PLAY],
        'sameAs': [APP_STORE, GOOGLE_PLAY],
    }


def block(text, lang, page, langs):
    """The tags for the page at /<lang>/<page>; lang None is the root page."""
    title = html.unescape(TITLE.search(text).group(1)).strip()
    m = DESC.search(text)
    if not m:
        raise SystemExit(f'no <meta name="description"> in /{lang or ""}/{page}')
    description = html.unescape(m.group(1))
    url = f'{ORIGIN}/{lang}/{page}' if lang else f'{ORIGIN}/'
    og_lang = lang or 'en'
    esc = lambda s: html.escape(s, quote=True)
    lines = ['<script src="/analytics.js" async></script>']
    if lang:
        lines.append(f'<link rel="canonical" href="{url}">')
    for code in langs:
        lines.append(f'<link rel="alternate" hreflang="{code}" href="{ORIGIN}/{code}/{page}">')
    lines.append(f'<link rel="alternate" hreflang="x-default" href="{ORIGIN}/{page}">'
                 if page == '' else
                 f'<link rel="alternate" hreflang="x-default" href="{ORIGIN}/en/{page}">')
    image, width, height = IMAGE
    lines += [
        '<meta property="og:type" content="website">',
        '<meta property="og:site_name" content="Pocket Agent">',
        f'<meta property="og:title" content="{esc(title)}">',
        f'<meta property="og:description" content="{esc(description)}">',
        f'<meta property="og:url" content="{url}">',
        f'<meta property="og:image" content="{ORIGIN}{image.format(lang=og_lang)}">',
        f'<meta property="og:image:width" content="{width}">',
        f'<meta property="og:image:height" content="{height}">',
        f'<meta property="og:locale" content="{LOCALE[og_lang]}">',
    ]
    for code in langs:
        if code != og_lang:
            lines.append(f'<meta property="og:locale:alternate" content="{LOCALE[code]}">')
    lines.append('<meta name="twitter:card" content="summary_large_image">')
    if page == '':
        graph = [website()] + ([app(lang, description)] if lang else [])
        lines.append(ld({'@context': 'https://schema.org', '@graph': graph}))
    return '\n<!-- seo -->\n' + '\n'.join(lines) + '\n<!-- /seo -->'


def write(path, lang, page, langs):
    text = path.read_text()
    new = HREFLANG.sub('', BLOCK.sub('', text))
    m = DESC.search(new)
    new = new[:m.end()] + block(new, lang, page, langs) + new[m.end():]
    if new != text:
        path.write_text(new)
        print('updated', path.relative_to(SITE.parent))


def sitemap(langs):
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">']
    for page in PAGES:
        for lang in langs:
            lines.append('  <url>')
            lines.append(f'    <loc>{ORIGIN}/{lang}/{page}</loc>')
            for code in langs:
                lines.append(f'    <xhtml:link rel="alternate" hreflang="{code}" href="{ORIGIN}/{code}/{page}"/>')
            lines.append('  </url>')
    lines.append('</urlset>')
    path = SITE / 'sitemap.xml'
    new = '\n'.join(lines) + '\n'
    if not path.exists() or path.read_text() != new:
        path.write_text(new)
        print('updated', path.relative_to(SITE.parent))


def main():
    langs = languages()
    write(SITE / 'index.html', None, '', langs)
    for lang in langs:
        for page in PAGES:
            write(SITE / lang / page / 'index.html', lang, page, langs)
    sitemap(langs)


main()
