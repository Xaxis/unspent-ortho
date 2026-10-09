// unspent.world: fills the downloads from /releases/latest.json and points the
// first button at the visitor's own system. The page reads whole without this
// script: every link it rewrites already goes somewhere true.
//
// latest.json is written by tools/deploy.sh from the newest published GitHub
// release (tools/site/latest.py): { version, published, url, builds: { macos |
// windows | linux: { name, url, size, sha256 } } }. No file, or no build for a
// system, and that card says so instead of offering a dead link.
(function () {
  "use strict";
  var NAMES = { macos: "macOS", windows: "Windows", linux: "Linux" };

  function system() {
    var p = ((navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || "").toLowerCase();
    var ua = navigator.userAgent.toLowerCase();
    if (/android|iphone|ipad|ipod/.test(ua) || (navigator.maxTouchPoints > 1 && /mac/.test(p))) return "touch";
    if (/mac/.test(p) || /mac os/.test(ua)) return "macos";
    if (/win/.test(p) || /windows/.test(ua)) return "windows";
    if (/linux|x11|cros/.test(p) || /linux/.test(ua)) return "linux";
    return "";
  }

  function mb(bytes) {
    return (bytes / 1048576).toFixed(0) + " MB";
  }

  function day(iso) {
    var d = new Date(iso);
    if (isNaN(d)) return "";
    return d.toISOString().slice(0, 10);
  }

  var mine = system();
  document.documentElement.setAttribute("data-system", mine || "other");
  var card = mine && document.querySelector('.build[data-system="' + mine + '"]');
  if (card) card.classList.add("yours");

  if (mine === "touch") {
    var touch = document.getElementById("touch-note");
    if (touch) touch.hidden = false;
  }

  fetch("/releases/latest.json", { cache: "no-cache" })
    .then(function (r) { return r.ok ? r.json() : null; })
    .catch(function () { return null; })
    .then(function (rel) {
      var builds = (rel && rel.builds) || {};
      document.querySelectorAll(".build[data-system]").forEach(function (el) {
        var sys = el.getAttribute("data-system");
        if (!NAMES[sys]) return; // the browser card is always the live build at /play
        var b = builds[sys];
        var btn = el.querySelector(".btn");
        var meta = el.querySelector(".meta");
        var sum = el.querySelector(".sum");
        if (!b) {
          btn.removeAttribute("href");
          btn.setAttribute("aria-disabled", "true");
          btn.textContent = "Not out yet";
          meta.textContent = rel ? "No " + NAMES[sys] + " build in " + rel.version + "." : "The first release is on its way. The browser build is here now.";
          return;
        }
        btn.href = b.url;
        btn.removeAttribute("aria-disabled");
        btn.textContent = "Download " + b.name.replace(/\.zip$/, "") ;
        meta.textContent = "Version " + rel.version + " / " + day(rel.published) + " / " + mb(b.size);
        if (sum && b.sha256) sum.textContent = "sha256 " + b.sha256;
      });
      var lead = document.getElementById("download-lead");
      if (lead) {
        var b = mine && builds[mine];
        if (b) {
          lead.href = b.url;
          lead.textContent = "Download for " + NAMES[mine];
        } else {
          lead.href = "#download";
          lead.textContent = "Mac, Windows, Linux";
        }
      }
      var ver = document.getElementById("release-version");
      if (ver && rel) {
        ver.textContent = rel.version;
        if (rel.url) ver.href = rel.url;
      }
    });
})();
