// Side menu: each page opens and closes to list its sections, the section in
// view is highlighted, and the menu opens/closes on narrow screens.
(function () {
  document.documentElement.classList.add('js');

  var nav = document.getElementById('side-nav');
  var ja = document.documentElement.lang === 'ja';
  var headings = Array.prototype.slice.call(document.querySelectorAll('main h2[id]'));
  var links = [];

  // Each top-level page becomes a group that opens and closes to show its
  // sections. The current page's sections come from this page; the others
  // are read from their pages in the background.
  function sectionList(items, base) {
    var list = document.createElement('ul');
    list.className = 'toc';
    items.forEach(function (h) {
      var li = document.createElement('li');
      var a = document.createElement('a');
      a.href = base + '#' + h.id;
      a.textContent = h.dataset.toc || h.textContent;
      li.appendChild(a);
      list.appendChild(li);
    });
    return list;
  }

  function makeGroup(li, link, open) {
    var row = document.createElement('div');
    row.className = 'nav-row';
    li.insertBefore(row, link);
    row.appendChild(link);
    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'nav-toggle';
    button.setAttribute('aria-label', (ja ? 'セクションを表示: ' : 'Show sections: ') + link.textContent);
    row.appendChild(button);
    var sub = document.createElement('div');
    sub.className = 'nav-sub';
    li.appendChild(sub);
    li.classList.add('group');
    var setOpen = function (o) {
      li.classList.toggle('open', o);
      button.setAttribute('aria-expanded', String(o));
    };
    setOpen(open);
    button.addEventListener('click', function () {
      setOpen(!li.classList.contains('open'));
    });
    return sub;
  }

  if (nav) {
    nav.querySelectorAll(':scope > ul > li').forEach(function (li) {
      var link = li.querySelector('a');
      if (!link) return;
      if (link.getAttribute('aria-current') === 'page') {
        if (!headings.length) return;
        var list = sectionList(headings, '');
        list.querySelectorAll('a').forEach(function (a) { links.push(a); });
        makeGroup(li, link, true).appendChild(list);
        return;
      }
      if (!window.fetch || !window.DOMParser) return;
      var href = link.getAttribute('href');
      fetch(href).then(function (r) { return r.ok ? r.text() : ''; }).then(function (html) {
        var doc = new DOMParser().parseFromString(html, 'text/html');
        var hs = Array.prototype.slice.call(doc.querySelectorAll('main h2[id]'));
        if (hs.length) makeGroup(li, link, false).appendChild(sectionList(hs, href));
      }).catch(function () {});
    });
  }

  if (links.length && 'IntersectionObserver' in window) {
    var visible = {};
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { visible[e.target.id] = e.isIntersecting; });
      var active = null;
      for (var i = 0; i < headings.length; i++) {
        if (visible[headings[i].id]) { active = headings[i].id; break; }
      }
      if (!active) return;
      links.forEach(function (a) {
        a.classList.toggle('active', a.getAttribute('href') === '#' + active);
      });
    }, { rootMargin: '0px 0px -60% 0px' });
    headings.forEach(function (h) { observer.observe(h); });
  }

  var toggle = document.querySelector('.menu-toggle');
  if (toggle && nav) {
    var setOpen = function (open) {
      toggle.setAttribute('aria-expanded', String(open));
      nav.classList.toggle('open', open);
    };
    toggle.addEventListener('click', function () {
      setOpen(toggle.getAttribute('aria-expanded') !== 'true');
    });
    nav.addEventListener('click', function (e) {
      if (e.target.closest('a')) setOpen(false);
    });
  }

  // Copy buttons on code blocks and on inline strings marked `.copy`.
  var label = ja ? 'コピー' : 'Copy';
  var done = ja ? 'コピーしました' : 'Copied';
  function copyButton(text) {
    var b = document.createElement('button');
    b.type = 'button';
    b.className = 'copy-btn';
    b.setAttribute('aria-label', label);
    b.title = label;
    b.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      var ok = function () {
        b.classList.add('copied');
        b.title = done;
        setTimeout(function () { b.classList.remove('copied'); b.title = label; }, 1500);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text()).then(ok, function () {});
      }
    });
    return b;
  }
  if (navigator.clipboard) {
    document.querySelectorAll('main pre').forEach(function (pre) {
      var code = pre.querySelector('code') || pre;
      pre.classList.add('has-copy');
      pre.appendChild(copyButton(function () { return code.textContent; }));
    });
    document.querySelectorAll('main .copy').forEach(function (el) {
      var wrap = document.createElement('span');
      wrap.className = 'copy-wrap';
      el.parentNode.insertBefore(wrap, el);
      wrap.appendChild(el);
      wrap.appendChild(copyButton(function () { return el.textContent; }));
    });
  }
})();
