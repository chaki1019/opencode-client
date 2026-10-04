// Side menu: each page opens and closes to list its sections, the section in
// view is highlighted, and the menu opens/closes on narrow screens.
(function () {
  document.documentElement.classList.add('js');
  var ja = document.documentElement.lang === 'ja';

  var nav = document.getElementById('side-nav');
  var headings = Array.prototype.slice.call(document.querySelectorAll('main h2[id]'));
  var links = [];

  // The menu (written by scripts/site_nav.py) lists every page's sections.
  // Groups open and close with their button; what the reader opened or closed
  // is kept across pages, and an inline script after the menu puts it back
  // before it is painted.
  if (nav) {
    var load = function () {
      try { return JSON.parse(localStorage.getItem('nav-open') || '{}'); } catch (e) { return {}; }
    };
    nav.querySelectorAll('.group').forEach(function (g) {
      var button = g.querySelector('.nav-toggle');
      var sync = function () {
        button.setAttribute('aria-expanded', String(g.classList.contains('open')));
      };
      sync();
      button.addEventListener('click', function () {
        g.classList.toggle('open');
        sync();
        var state = load();
        state[g.dataset.key] = g.classList.contains('open');
        try { localStorage.setItem('nav-open', JSON.stringify(state)); } catch (e) {}
      });
    });
    var current = nav.querySelector('a[aria-current="page"]');
    var group = current && current.closest('.group');
    if (group) {
      links = Array.prototype.slice.call(group.querySelectorAll('.toc a'));
      // The current page starts open; remember that, so it stays open after
      // moving to another page until the reader closes it.
      var state = load();
      if (!(group.dataset.key in state)) {
        state[group.dataset.key] = group.classList.contains('open');
        try { localStorage.setItem('nav-open', JSON.stringify(state)); } catch (e) {}
      }
    }
    window.addEventListener('pagehide', function () {
      try { sessionStorage.setItem('nav-scroll', String(nav.scrollTop)); } catch (e) {}
    });
    // Animate only changes the reader makes, not the state put back on load.
    requestAnimationFrame(function () {
      requestAnimationFrame(function () { nav.classList.add('ready'); });
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
