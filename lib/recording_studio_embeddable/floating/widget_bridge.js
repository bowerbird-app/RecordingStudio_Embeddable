/* Talks to the parent launcher. targetOrigin is the meta origin, never "*". */
(function () {
  var meta = document.querySelector("meta[name='recording-studio-widget-parent-origin']");
  var parentOrigin = meta && meta.getAttribute("content");
  if (!parentOrigin || parentOrigin === "*") return;
  if (window.parent === window) return;

  function post(type, extra) {
    var payload = { source: "recording-studio-widget-popup", type: type };
    if (extra) {
      Object.keys(extra).forEach(function (key) { payload[key] = extra[key]; });
    }
    window.parent.postMessage(payload, parentOrigin);
  }

  window.addEventListener("message", function (event) {
    if (event.origin !== parentOrigin) return;
    if (event.source !== window.parent) return;
    if (!event.data || event.data.source !== "recording-studio-widget") return;
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") post("close");
  });

  document.addEventListener("click", function (event) {
    var target = event.target;
    if (target && target.closest && target.closest("[data-widget-close]")) post("close");
  });

  function sendSize() {
    post("resize", { height: document.documentElement.scrollHeight });
  }

  window.addEventListener("load", sendSize);
  if (window.ResizeObserver) new ResizeObserver(sendSize).observe(document.documentElement);
})();
