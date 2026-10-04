// Side menu: lists the current page's sections under its entry, highlights
// the section in view, and opens/closes the menu on narrow screens.
(function () {
  document.documentElement.classList.add('js');

  var nav = document.getElementById('side-nav');
  var current = nav && nav.querySelector('a[aria-current="page"]');
  var headings = Array.prototype.slice.call(document.querySelectorAll('main h2[id]'));
  var links = [];

  if (current && headings.length) {
    var list = document.createElement('ul');
    list.className = 'toc';
    headings.forEach(function (h) {
      var li = document.createElement('li');
      var a = document.createElement('a');
      a.href = '#' + h.id;
      a.textContent = h.textContent;
      li.appendChild(a);
      list.appendChild(li);
      links.push(a);
    });
    current.parentNode.appendChild(list);
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
})();
