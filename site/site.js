// Side menu: each page opens and closes to list its sections, the section in
// view is highlighted, and the menu opens/closes on narrow screens.
(function () {
  document.documentElement.classList.add('js');
  var ja = document.documentElement.lang === 'ja';

  var nav = document.getElementById('side-nav');
  var headings = Array.prototype.slice.call(document.querySelectorAll('main h2[id]'));
  var links = [];

  // The menu (written by scripts/site_nav.py) lists every page's sections.
  // Groups open and close with the page name; what the reader opened or closed
  // is kept across pages, and an inline script after the menu puts it back
  // before it is painted.
  if (nav) {
    var load = function () {
      try { return JSON.parse(localStorage.getItem('nav-open') || '{}'); } catch (e) { return {}; }
    };
    nav.querySelectorAll('.group').forEach(function (g) {
      var button = g.querySelector('.nav-head');
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
    var group = nav.querySelector('.group.current');
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

  // Highlight the section being read: the last heading that has reached the
  // upper part of the window, or the last one in view once the page cannot
  // scroll further. A section picked from the menu (or the address) stays
  // highlighted until the reader scrolls by themselves, because a short
  // section near the end may never reach the top.
  if (links.length) {
    var picked = null;
    var mark = function (id) {
      // Above the first heading, the page's overview entry ("#").
      links.forEach(function (a) {
        a.classList.toggle('active', a.getAttribute('href') === '#' + (id || ''));
      });
    };
    var update = function () {
      if (picked) return mark(picked);
      var line = window.innerHeight * 0.3;
      var atEnd = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 2;
      var active = null;
      // At the very top the overview entry stays highlighted.
      if (window.scrollY > 0) headings.forEach(function (h) {
        var top = h.getBoundingClientRect().top;
        if (top <= line || (atEnd && top < window.innerHeight)) active = h.id;
      });
      mark(active);
    };
    var pick = function () {
      var id = decodeURIComponent(location.hash.slice(1));
      picked = document.getElementById(id) && headings.some(function (h) { return h.id === id; }) ? id : null;
      update();
    };
    var release = function () {
      if (picked) { picked = null; update(); }
    };
    var queued = false;
    window.addEventListener('scroll', function () {
      if (queued) return;
      queued = true;
      requestAnimationFrame(function () { queued = false; update(); });
    }, { passive: true });
    window.addEventListener('resize', update);
    window.addEventListener('hashchange', pick);
    ['wheel', 'touchmove'].forEach(function (t) {
      window.addEventListener(t, release, { passive: true });
    });
    window.addEventListener('keydown', function (e) {
      if (/^(Arrow|Page|Home|End| )/.test(e.key)) release();
    });
    links.forEach(function (a) {
      a.addEventListener('click', function () {
        // Same hash again: hashchange does not fire.
        if (a.getAttribute('href') === location.hash) setTimeout(pick);
      });
    });
    if (location.hash) pick(); else update();
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
