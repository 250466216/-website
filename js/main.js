/* =========================================================
   光影志 LUMINA · 页面交互
   js/main.js
   ---------------------------------------------------------
   1. 作品集渲染与分类筛选
   2. 大图查看器（灯箱）
   3. 顶部导航（滚动样式 / 移动端菜单 / 当前区块高亮）
   4. 滚动出现动画
   5. 数字滚动统计
   6. 联系表单校验（纯前端演示）
   7. 回到顶部
   ========================================================= */

(function () {
  'use strict';

  /* ---------- 基础数据 ---------- */
  var CATEGORY_LABELS = window.PHOTO_CATEGORIES || {};
  var ALL_PHOTOS = Array.isArray(window.PHOTOS) ? window.PHOTOS.slice() : [];

  var els = {
    header: document.getElementById('siteHeader'),
    nav: document.getElementById('mainNav'),
    navToggle: document.getElementById('navToggle'),
    grid: document.getElementById('galleryGrid'),
    empty: document.getElementById('galleryEmpty'),
    filters: document.getElementById('filters'),
    toTop: document.getElementById('toTop'),
    year: document.getElementById('year'),
    form: document.getElementById('contactForm'),
    formStatus: document.getElementById('formStatus')
  };

  var lightbox = {
    root: document.getElementById('lightbox'),
    img: document.getElementById('lightboxImage'),
    title: document.getElementById('lightboxTitle'),
    category: document.getElementById('lightboxCategory'),
    meta: document.getElementById('lightboxMeta'),
    counter: document.getElementById('lightboxCounter'),
    close: document.getElementById('lightboxClose'),
    prev: document.getElementById('lightboxPrev'),
    next: document.getElementById('lightboxNext')
  };

  /* 当前筛选中可见的作品（灯箱只在这些作品之间切换） */
  var visiblePhotos = ALL_PHOTOS.slice();

  /* ---------- 小工具 ---------- */
  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
  }

  function categoryLabel(key) {
    return CATEGORY_LABELS[key] || '其他';
  }

  function metaLine(photo) {
    return [photo.place, photo.year].filter(Boolean).join(' · ');
  }

  /* 无障碍描述：标题 + 题材 + 地点 + 年份，缺哪项就跳过哪项 */
  function altText(photo) {
    var parts = [photo.title, categoryLabel(photo.category) + '摄影作品'];
    if (photo.place) parts.push(photo.place + '拍摄');
    if (photo.year) parts.push(photo.year + '年');
    return parts.filter(Boolean).join('，');
  }

  /* =========================================================
     1. 作品集渲染与分类筛选
     ========================================================= */
  function createTile(photo, index) {
    var item = el('article', 'gallery-item');
    item.dataset.category = photo.category || 'other';
    item.dataset.index = String(index);

    var thumb = el('button', 'gallery-thumb');
    thumb.type = 'button';
    thumb.setAttribute('aria-label', '查看作品：' + photo.title);

    var img = document.createElement('img');
    /* 网格用缩略图（thumb），打开大图时再加载原图（src）——作品多时首屏快很多 */
    img.src = photo.thumb || photo.src;
    img.alt = altText(photo);
    img.loading = index < 4 ? 'eager' : 'lazy';
    img.decoding = 'async';

    var overlay = el('span', 'gallery-overlay');
    overlay.appendChild(el('span', 'gallery-cat', categoryLabel(photo.category)));
    overlay.appendChild(el('span', 'gallery-name', photo.title));
    overlay.appendChild(el('span', 'gallery-meta', metaLine(photo)));

    thumb.appendChild(img);
    thumb.appendChild(overlay);
    item.appendChild(thumb);

    /* 入场动画：按顺序轻微错开 */
    item.classList.add('is-in');
    item.style.animationDelay = Math.min(index, 9) * 45 + 'ms';

    thumb.addEventListener('click', function () {
      openLightbox(index);
    });

    return item;
  }

  function renderGallery(photos) {
    visiblePhotos = photos.slice();

    els.grid.innerHTML = '';
    var fragment = document.createDocumentFragment();
    photos.forEach(function (photo, index) {
      fragment.appendChild(createTile(photo, index));
    });
    els.grid.appendChild(fragment);

    /* 每次重排后检查最后一行是否落单 */
    scheduleOrphanRowFix();

    var isEmpty = photos.length === 0;
    els.grid.hidden = isEmpty;
    if (els.empty) els.empty.hidden = !isEmpty;
    if (!isEmpty) buildLazyObserver();
  }

  function updateFilterCounts() {
    if (!els.filters) return;
    var counts = { all: ALL_PHOTOS.length };
    ALL_PHOTOS.forEach(function (photo) {
      var key = photo.category || 'other';
      counts[key] = (counts[key] || 0) + 1;
    });

    els.filters.querySelectorAll('.filter-count').forEach(function (badge) {
      var key = badge.dataset.count;
      badge.textContent = String(counts[key] || 0);
    });
  }

  function setFilter(key) {
    if (!els.filters) return;
    els.filters.querySelectorAll('.filter-btn').forEach(function (btn) {
      var active = btn.dataset.filter === key;
      btn.classList.toggle('is-active', active);
      btn.setAttribute('aria-pressed', String(active));
    });

    renderGallery(
      key === 'all'
        ? ALL_PHOTOS
        : ALL_PHOTOS.filter(function (photo) {
            return (photo.category || 'other') === key;
          })
    );
  }

  function initGallery() {
    if (!els.grid) return;

    updateFilterCounts();

    if (els.filters) {
      els.filters.addEventListener('click', function (event) {
        var btn = event.target.closest('.filter-btn');
        if (btn) setFilter(btn.dataset.filter);
      });
    }

    renderGallery(ALL_PHOTOS);
  }

  /* 图片懒加载兜底：不支持 loading="lazy" 的浏览器立即加载全部 */
  function buildLazyObserver() {
    if ('loading' in HTMLImageElement.prototype) return;
    els.grid.querySelectorAll('img').forEach(function (img) {
      img.loading = 'eager';
    });
  }

  /* ---------- 版式兜底：最后一行不落单 ----------
     网格是固定列数（桌面 4 列 / 窄屏 2 列），只要作品数量是列数的整数倍，
     最后一行就会刚好填满。万一个数除不尽、最后一行只剩一张，
     就把那一张拉满整行，避免出现「凸出来一小块」的观感。 */
  var orphanTimer = null;

  function fixOrphanRow() {
    if (!els.grid || els.grid.hidden) return;

    var tiles = Array.prototype.slice.call(els.grid.children);
    if (!tiles.length) return;

    /* 先撤销上一次的修正，按当前宽度重新计算 */
    var previous = els.grid.querySelector('.gallery-item.is-solo');
    if (previous) {
      previous.classList.remove('is-solo');
      previous.style.gridColumn = '';
    }
    if (tiles.length < 2) return;

    var gridWidth = els.grid.clientWidth;
    var tileWidth = tiles[0].getBoundingClientRect().width;
    if (!gridWidth || !tileWidth) return; /* 隐藏或未布局时直接跳过 */

    var gap = parseFloat(window.getComputedStyle(els.grid).columnGap) || 0;
    var columns = Math.round((gridWidth + gap) / (tileWidth + gap));
    if (!isFinite(columns) || columns < 2) return;

    var lastTop = tiles[tiles.length - 1].offsetTop;
    var lastRow = tiles.filter(function (tile) {
      return tile.offsetTop === lastTop;
    });

    if (lastRow.length === 1) {
      var solo = lastRow[0];
      solo.classList.add('is-solo');
      solo.style.gridColumn = 'span ' + columns;
    }
  }

  function scheduleOrphanRowFix() {
    if (orphanTimer) window.clearTimeout(orphanTimer);
    orphanTimer = window.setTimeout(fixOrphanRow, 60);
  }

  function initOrphanRowFix() {
    if (!els.grid) return;
    window.addEventListener('resize', scheduleOrphanRowFix, { passive: true });

    /* 字体 / 图片加载完成后宽度可能变化，再兜底算一次 */
    window.addEventListener('load', scheduleOrphanRowFix);
  }

  /* =========================================================
     2. 大图查看器（灯箱）
     ========================================================= */
  var currentIndex = 0;
  var lastFocused = null;
  var closeTimer = null;

  /* 与 css/style.css 里 .lightbox 的 transition: opacity 0.3s ease 保持一致 */
  var LIGHTBOX_FADE_MS = 300;

  function photoAt(index) {
    var total = visiblePhotos.length;
    if (!total) return null;
    return visiblePhotos[((index % total) + total) % total];
  }

  function showLightboxPhoto(index) {
    var photo = photoAt(index);
    if (!photo) return;

    currentIndex = index;

    lightbox.img.src = photo.src;
    lightbox.img.alt = altText(photo);
    lightbox.title.textContent = photo.title;
    lightbox.category.textContent = categoryLabel(photo.category);

    var parts = [metaLine(photo), photo.camera].filter(Boolean);
    lightbox.meta.textContent = parts.join(' · ');
    lightbox.counter.textContent =
      String(currentIndex + 1).padStart(2, '0') + ' / ' + String(visiblePhotos.length).padStart(2, '0');

    /* 预加载前后各一张，切换更顺滑 */
    [index + 1, index - 1].forEach(function (i) {
      var neighbour = photoAt(i);
      if (neighbour) new Image().src = neighbour.src;
    });
  }

  function openLightbox(index) {
    if (!lightbox.root || !visiblePhotos.length) return;

    /* 上一次关闭还在淡出时，取消收尾定时器，直接淡回来 */
    if (closeTimer) {
      window.clearTimeout(closeTimer);
      closeTimer = null;
    }

    lastFocused = document.activeElement;
    lightbox.root.classList.remove('is-closing');
    lightbox.root.hidden = false;

    /* 先让浏览器接受「display: flex + opacity: 0」，再加 .is-open；
       否则同一帧里改 display 和 opacity，0.3s 淡入不会触发 */
    void lightbox.root.offsetWidth;
    lightbox.root.classList.add('is-open');

    document.body.classList.add('is-locked');
    showLightboxPhoto(index);
    if (lightbox.close) lightbox.close.focus();
  }

  function closeLightbox() {
    if (!lightbox.root || lightbox.root.hidden) return;
    if (lightbox.root.classList.contains('is-closing')) return;

    /* 先淡出（1 → 0），过渡结束后再真正 hidden：
       若立刻 hidden，display: none 会中断过渡，看起来是「啪」地消失 */
    lightbox.root.classList.remove('is-open');
    lightbox.root.classList.add('is-closing');
    document.body.classList.remove('is-locked');

    closeTimer = window.setTimeout(function () {
      closeTimer = null;
      lightbox.root.hidden = true;
      lightbox.root.classList.remove('is-closing');
      lightbox.img.removeAttribute('src');
    }, LIGHTBOX_FADE_MS);

    if (lastFocused && typeof lastFocused.focus === 'function') lastFocused.focus();
  }

  function stepLightbox(delta) {
    if (!lightbox.root || lightbox.root.hidden || !visiblePhotos.length) return;
    if (lightbox.root.classList.contains('is-closing')) return; /* 淡出中不再切换 */
    showLightboxPhoto(currentIndex + delta);
  }

  function initLightbox() {
    if (!lightbox.root) return;

    lightbox.close.addEventListener('click', closeLightbox);
    lightbox.prev.addEventListener('click', function () { stepLightbox(-1); });
    lightbox.next.addEventListener('click', function () { stepLightbox(1); });

    /* 点击图片以外的遮罩区域关闭 */
    lightbox.root.addEventListener('click', function (event) {
      if (event.target === lightbox.root) closeLightbox();
    });

    /* 键盘操作：Esc 关闭，← → 切换 */
    document.addEventListener('keydown', function (event) {
      if (lightbox.root.hidden) return;
      if (lightbox.root.classList.contains('is-closing')) return;
      if (event.key === 'Escape') closeLightbox();
      else if (event.key === 'ArrowLeft') stepLightbox(-1);
      else if (event.key === 'ArrowRight') stepLightbox(1);
    });

    /* 移动端左右滑动切换 */
    var touchStartX = null;
    lightbox.root.addEventListener('touchstart', function (event) {
      touchStartX = event.changedTouches[0].clientX;
    }, { passive: true });

    lightbox.root.addEventListener('touchend', function (event) {
      if (touchStartX === null) return;
      var deltaX = event.changedTouches[0].clientX - touchStartX;
      touchStartX = null;
      if (Math.abs(deltaX) > 50) stepLightbox(deltaX > 0 ? -1 : 1);
    }, { passive: true });
  }

  /* =========================================================
     3. 顶部导航
     ========================================================= */
  function closeMobileNav() {
    if (!els.nav || !els.navToggle) return;
    els.nav.classList.remove('is-open');
    els.navToggle.setAttribute('aria-expanded', 'false');
    els.navToggle.setAttribute('aria-label', '打开导航菜单');
    els.header.classList.remove('is-open');
  }

  function initHeader() {
    if (!els.header) return;

    var onScroll = function () {
      els.header.classList.toggle('is-scrolled', window.scrollY > 40);
      if (els.toTop) els.toTop.classList.toggle('is-visible', window.scrollY > 620);
    };

    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });

    if (els.navToggle && els.nav) {
      els.navToggle.addEventListener('click', function () {
        var isOpen = els.nav.classList.toggle('is-open');
        els.navToggle.setAttribute('aria-expanded', String(isOpen));
        els.navToggle.setAttribute('aria-label', isOpen ? '关闭导航菜单' : '打开导航菜单');
        els.header.classList.toggle('is-open', isOpen);
      });

      /* 点击菜单项后收起（移动端） */
      els.nav.addEventListener('click', function (event) {
        if (event.target.closest('a')) closeMobileNav();
      });

      /* 点击页面其他区域 / 按 Esc 收起 */
      document.addEventListener('click', function (event) {
        if (!els.nav.classList.contains('is-open')) return;
        if (els.header.contains(event.target)) return;
        closeMobileNav();
      });

      document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') closeMobileNav();
      });

      window.addEventListener('resize', function () {
        if (window.innerWidth > 860) closeMobileNav();
      });
    }
  }

  /* 滚动时高亮当前区块对应的导航项 */
  function initScrollSpy() {
    var links = Array.prototype.slice.call(document.querySelectorAll('.main-nav a[href^="#"]'));
    if (!links.length || !('IntersectionObserver' in window)) return;

    var map = {};
    var sections = [];

    links.forEach(function (link) {
      var section = document.querySelector(link.getAttribute('href'));
      if (!section) return;
      map[section.id] = link;
      sections.push(section);
    });

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          links.forEach(function (link) { link.classList.remove('is-active'); });
          var link = map[entry.target.id];
          if (link) link.classList.add('is-active');
        });
      },
      { rootMargin: '-45% 0px -50% 0px', threshold: 0 }
    );

    sections.forEach(function (section) { observer.observe(section); });
  }

  /* =========================================================
     4. 滚动出现动画
     ========================================================= */
  function initReveal() {
    var targets = document.querySelectorAll('.reveal');
    if (!targets.length) return;

    if (!('IntersectionObserver' in window)) {
      targets.forEach(function (node) { node.classList.add('is-visible'); });
      return;
    }

    var observer = new IntersectionObserver(
      function (entries, obs) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add('is-visible');
          obs.unobserve(entry.target);
        });
      },
      { rootMargin: '0px 0px -12% 0px', threshold: 0.12 }
    );

    targets.forEach(function (node) { observer.observe(node); });
  }

  /* =========================================================
     5. 数字滚动统计
     ========================================================= */
  function initCounters() {
    var nodes = Array.prototype.slice.call(document.querySelectorAll('[data-count-to]'));
    if (!nodes.length) return;

    var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    var run = function (node) {
      var target = parseInt(node.dataset.countTo, 10) || 0;
      var suffix = node.dataset.suffix || '';

      if (reduced) {
        node.textContent = target + suffix;
        return;
      }

      var duration = 1200;
      var startTime = null;

      var tick = function (timestamp) {
        if (startTime === null) startTime = timestamp;
        var progress = Math.min((timestamp - startTime) / duration, 1);
        var eased = 1 - Math.pow(1 - progress, 3);
        node.textContent = Math.round(target * eased) + suffix;
        if (progress < 1) window.requestAnimationFrame(tick);
      };

      window.requestAnimationFrame(tick);
    };

    if (!('IntersectionObserver' in window)) {
      nodes.forEach(run);
      return;
    }

    var observer = new IntersectionObserver(
      function (entries, obs) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          run(entry.target);
          obs.unobserve(entry.target);
        });
      },
      { threshold: 0.4 }
    );

    nodes.forEach(function (node) { observer.observe(node); });
  }

  /* =========================================================
     6. 联系表单校验（纯前端演示，没有后端接口）
     ========================================================= */
  function initForm() {
    if (!els.form) return;

    var showStatus = function (message, ok) {
      if (!els.formStatus) return;
      els.formStatus.textContent = message;
      els.formStatus.classList.toggle('is-ok', ok);
      els.formStatus.classList.toggle('is-error', !ok);
    };

    var validateField = function (field) {
      var value = (field.value || '').trim();
      var valid;

      if (field.type === 'email') {
        valid = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value);
      } else {
        valid = value.length > 0;
      }

      var wrap = field.closest('.field');
      if (wrap) wrap.classList.toggle('has-error', !valid);
      return valid;
    };

    var requiredFields = Array.prototype.slice.call(
      els.form.querySelectorAll('input[required], textarea[required]')
    );

    els.form.addEventListener('submit', function (event) {
      event.preventDefault();

      var firstInvalid = null;
      requiredFields.forEach(function (field) {
        if (!validateField(field) && !firstInvalid) firstInvalid = field;
      });

      if (firstInvalid) {
        firstInvalid.focus();
        showStatus('请先补全标有 * 的内容。', false);
        return;
      }

      showStatus('已收到你的留言，我会尽快回复。（演示环境，并未真实发送邮件）', true);
      els.form.reset();
    });

    els.form.addEventListener('input', function (event) {
      if (event.target.matches('input[required], textarea[required]')) {
        validateField(event.target);
      }
    });
  }

  /* =========================================================
     7. 回到顶部 & 页脚年份 & 启动
     ========================================================= */
  function initToTop() {
    if (!els.toTop) return;
    els.toTop.addEventListener('click', function () {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
  }

  function initYear() {
    if (els.year) els.year.textContent = String(new Date().getFullYear());
  }

  function init() {
    initGallery();
    initOrphanRowFix();
    initLightbox();
    initHeader();
    initScrollSpy();
    initReveal();
    initCounters();
    initForm();
    initToTop();
    initYear();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
