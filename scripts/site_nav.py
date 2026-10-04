#!/usr/bin/env python3
"""Writes the side menu into every page under site/.

Each page's entry lists its sections, taken from the page's own
`<h2 id>` headings (`data-toc` wins over the heading text). Run it from the
repository root after adding a page or changing a heading:

    python3 scripts/site_nav.py

Pages are listed in PAGES; languages are the folders under site/ that hold
an index.html.
"""
import html
import pathlib
import re

SITE = pathlib.Path(__file__).resolve().parent.parent / 'site'
# (path under the language folder, label per language)
PAGES = [
    ('', {'ja': 'トップ', 'en': 'Home'}),
    ('connect/', {'ja': 'つなぎ方', 'en': 'Connecting'}),
    ('support/', {'ja': 'サポート', 'en': 'Support'}),
    ('privacy/', {'ja': 'プライバシーポリシー', 'en': 'Privacy policy'}),
]
TOGGLE = {'ja': 'セクションの表示を切り替え: ', 'en': 'Show or hide sections: '}
NAV = re.compile(r'(<nav class="side-nav" id="side-nav"[^>]*>\n)(.*?)(\n    <div class="side-lang">)', re.S)
H2 = re.compile(r'<h2 id="([^"]+)"(?: data-toc="([^"]*)")?[^>]*>(.*?)</h2>', re.S)
TAG = re.compile(r'<[^>]+>')
# Runs before the menu is painted: puts back the groups the reader opened or
# closed on earlier pages, and the menu's scroll position.
RESTORE = (
    '<script>(function(){var n=document.getElementById("side-nav"),s={};'
    'try{s=JSON.parse(localStorage.getItem("nav-open")||"{}");'
    'n.scrollTop=+sessionStorage.getItem("nav-scroll")||0}catch(e){}'
    'n.querySelectorAll(".group").forEach(function(g){var k=g.dataset.key;'
    'if(k in s)g.classList.toggle("open",!!s[k])})})()</script>'
)


def sections(path):
    text = path.read_text()
    main = text[text.index('<main>'):]
    for m in H2.finditer(main):
        label = m.group(2) or TAG.sub('', m.group(3))
        yield m.group(1), html.unescape(label).strip()


def menu(lang, current):
    lines = ['    <ul>']
    for page, labels in PAGES:
        href = f'/{lang}/{page}'
        here = page == current
        items = list(sections(SITE / lang / page / 'index.html'))
        label = labels[lang]
        attr = ' aria-current="page"' if here else ''
        lines.append(f'      <li class="group{" open" if here else ""}" data-key="{href}">')
        lines.append(f'        <div class="nav-row"><a href="{href}"{attr}>{label}</a>'
                     f'<button type="button" class="nav-toggle" aria-label="{TOGGLE[lang]}{label}"></button></div>')
        lines.append('        <div class="nav-sub"><ul class="toc">')
        for id_, text in items:
            target = f'#{id_}' if here else f'{href}#{id_}'
            lines.append(f'          <li><a href="{target}">{html.escape(text, quote=False)}</a></li>')
        lines.append('        </ul></div>')
        lines.append('      </li>')
    lines.append('    </ul>')
    return '\n'.join(lines)


def main():
    for lang_dir in sorted(p for p in SITE.iterdir() if (p / 'index.html').exists() and p.name != 'img'):
        if lang_dir == SITE:
            continue
        lang = lang_dir.name
        for page, _ in PAGES:
            path = lang_dir / page / 'index.html'
            text = path.read_text()
            new = NAV.sub(lambda m: m.group(1) + menu(lang, page) + m.group(3), text, count=1)
            new = re.sub(r'\n  </nav>\n(?:<script>\(function\(\)\{var n=document\.getElementById\("side-nav"\).*?</script>\n)?',
                         '\n  </nav>\n' + RESTORE + '\n', new, count=1, flags=re.S)
            if '<script>document.documentElement.classList.add("js")</script>' not in new:
                new = new.replace('<script src="/site.js" defer></script>',
                                  '<script>document.documentElement.classList.add("js")</script>\n<script src="/site.js" defer></script>', 1)
            if new != text:
                path.write_text(new)
                print('updated', path.relative_to(SITE.parent))


main()
