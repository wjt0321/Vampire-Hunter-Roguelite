(function () {
  'use strict';
  var doc = document;
  doc.documentElement.className += ' js';

  /* ---------- 移动端导航 ---------- */
  var nav = doc.getElementById('nav');
  var navToggle = doc.getElementById('navToggle');
  if (nav && navToggle) {
    navToggle.addEventListener('click', function () {
      var open = nav.classList.toggle('on');
      navToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    nav.addEventListener('click', function (ev) {
      if (ev.target.tagName === 'A') {
        nav.classList.remove('on');
        navToggle.setAttribute('aria-expanded', 'false');
      }
    });
  }

  /* ---------- 滚动显现 ---------- */
  var revealables = doc.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('in');
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -60px 0px' });
    revealables.forEach(function (el, i) {
      el.style.transitionDelay = (i % 4) * 70 + 'ms';
      io.observe(el);
    });
  } else {
    revealables.forEach(function (el) { el.classList.add('in'); });
  }

  /* ---------- 数字滚动 ---------- */
  var counters = doc.querySelectorAll('[data-count]');
  function runCounter(el) {
    var target = parseInt(el.getAttribute('data-count'), 10) || 0;
    var start = performance.now();
    var dur = 1100;
    function tick(now) {
      var p = Math.min((now - start) / dur, 1);
      var eased = 1 - Math.pow(1 - p, 3);
      el.textContent = String(Math.round(target * eased));
      if (p < 1) requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  }
  if ('IntersectionObserver' in window && counters.length) {
    var co = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          runCounter(entry.target);
          co.unobserve(entry.target);
        }
      });
    }, { threshold: 0.6 });
    counters.forEach(function (el) { co.observe(el); });
  } else {
    counters.forEach(function (el) { el.textContent = el.getAttribute('data-count'); });
  }

  /* ---------- 灯箱 ---------- */
  var shots = Array.prototype.slice.call(doc.querySelectorAll('.shot[data-full]'));
  var lb = doc.getElementById('lightbox');
  var lbImg = doc.getElementById('lbImg');
  var lbCap = doc.getElementById('lbCap');
  var lbClose = doc.getElementById('lbClose');
  var lbPrev = doc.getElementById('lbPrev');
  var lbNext = doc.getElementById('lbNext');
  var current = 0;

  function showShot(i) {
    if (!shots.length) return;
    current = (i + shots.length) % shots.length;
    var fig = shots[current];
    lbImg.src = fig.getAttribute('data-full');
    lbImg.alt = fig.getAttribute('data-cap') || '';
    lbCap.textContent = fig.getAttribute('data-cap') || '';
    lb.classList.add('on');
    lb.setAttribute('aria-hidden', 'false');
    doc.body.style.overflow = 'hidden';
  }
  function hideShot() {
    lb.classList.remove('on');
    lb.setAttribute('aria-hidden', 'true');
    doc.body.style.overflow = '';
  }
  shots.forEach(function (fig, i) {
    fig.addEventListener('click', function () { showShot(i); });
  });
  if (lbClose) lbClose.addEventListener('click', hideShot);
  if (lbPrev) lbPrev.addEventListener('click', function (e) { e.stopPropagation(); showShot(current - 1); });
  if (lbNext) lbNext.addEventListener('click', function (e) { e.stopPropagation(); showShot(current + 1); });
  if (lb) lb.addEventListener('click', function (e) { if (e.target === lb) hideShot(); });
  doc.addEventListener('keydown', function (e) {
    if (!lb || !lb.classList.contains('on')) return;
    if (e.key === 'Escape') hideShot();
    if (e.key === 'ArrowLeft') showShot(current - 1);
    if (e.key === 'ArrowRight') showShot(current + 1);
  });

  /* ---------- 成就跑马灯 ---------- */
  var track = doc.getElementById('achTrack');
  if (track) {
    var names = ['boss_killer','crypt_breaker','elite_hunter','evolutionist','expert_hunter','exterminator','first_blood','flawless_victory','jack_of_all_trades','maxed_out','novice_hunter','prince_slayer','rest_stop','rich_hunter','room_explorer','shopaholic','speed_runner','survivor','throne_breaker','treasure_hunter','vampire_slayer','wave_master','weapon_master','werewolf_hunter','zombie_hunter'].map(function (n) {
      return 'assets/img/achievements/ach_' + n + '.png';
    });
    var html = '';
    for (var pass = 0; pass < 2; pass++) {
      names.forEach(function (src) {
        html += '<img src="' + src + '" alt="成就徽章" loading="lazy">';
      });
    }
    track.innerHTML = html;
  }

  /* ---------- 敌人精灵：按帧数贴图并播放 ---------- */
  var FRAMES = {
    bat_fly: 4, zombie_walk: 6, skeleton_idle: 4, vampire_idle: 4,
    werewolf_idle: 4, gargoyle_idle: 2, exploder_walk: 4, mage_cast: 4,
    summoner_cast: 4, prince_idle: 4, elite_vampire_idle: 4
  };
  doc.querySelectorAll('.sprite[data-enemy]').forEach(function (el) {
    var key = el.getAttribute('data-enemy');
    var frames = FRAMES[key] || 4;
    el.style.backgroundImage = 'url(assets/img/enemies/' + key + '.png)';
    el.style.backgroundSize = (frames * 100) + '% 100%';
    el.style.animationName = 'sp' + frames;
    el.style.animationDuration = frames >= 6 ? '1.1s' : '1.4s';
  });
})();

