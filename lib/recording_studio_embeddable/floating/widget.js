/* Recording Studio floating launcher. Classic script, no dependencies.
   Reads document.currentScript[data-embed]. Optional data-config skips the fetch. */
(function () {
  var STYLE_ID = "recording-studio-floating-widget-style";
  var HOST = "recording-studio-widget";
  var POPUP = "recording-studio-widget-popup";

  function api() {
    if (!window.__recordingStudioFloatingWidget) {
      window.__recordingStudioFloatingWidget = { scan: scan, openOrder: [] };
      installGlobals();
    }
    return window.__recordingStudioFloatingWidget;
  }

  function installGlobals() {
    if (document.getElementById(STYLE_ID)) return;
    var style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = [
      "[" + attr("data-recording-studio-widget") + "]{position:fixed;z-index:2147483000;bottom:var(--rsw-edge,20px);display:flex;flex-direction:column;gap:12px;align-items:flex-end;max-width:calc(100vw - 16px);font:16px/1.4 system-ui,sans-serif;}",
      "[" + attr("data-position") + "='bottom-right']{right:var(--rsw-edge,20px);left:auto;}",
      "[" + attr("data-position") + "='bottom-left']{left:var(--rsw-edge,20px);right:auto;align-items:flex-start;}",
      "[" + attr("data-recording-studio-widget-stage") + "] [" + attr("data-recording-studio-widget") + "]{position:absolute;}",
      "[" + attr("data-widget-launcher") + "]{appearance:none;border:0;cursor:pointer;width:56px;height:56px;border-radius:999px;background:var(--rsw-bg,#111827);color:var(--rsw-fg,#fff);display:flex;align-items:center;justify-content:center;box-shadow:0 8px 24px rgba(0,0,0,.18);}",
      "[" + attr("data-widget-launcher") + "] img{width:28px;height:28px;object-fit:cover;border-radius:999px;}",
      "[" + attr("data-widget-popup") + "]{display:none;flex-direction:column;width:min(var(--rsw-width,380px),calc(100vw - 24px));height:min(var(--rsw-height,560px),calc(100vh - 96px - env(safe-area-inset-bottom)));background:#fff;color:#111;border-radius:16px;overflow:hidden;box-shadow:0 16px 48px rgba(0,0,0,.2);}",
      "[" + attr("data-open") + "='true'] [" + attr("data-widget-popup") + "]{display:flex;}",
      "[" + attr("data-widget-bar") + "]{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 12px;background:var(--rsw-bg,#111827);color:var(--rsw-fg,#fff);}",
      "[" + attr("data-widget-close") + "]{appearance:none;border:0;background:transparent;color:inherit;cursor:pointer;font:inherit;}",
      "[" + attr("data-recording-studio-widget-frame") + "]{flex:1;width:100%;border:0;background:#fff;}",
      "@media (max-width:640px){[" + attr("data-layout") + "='fullscreen'][" + attr("data-open") + "='true']{inset:0;width:auto;height:auto;max-width:none;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);}[" + attr("data-layout") + "='fullscreen'][" + attr("data-open") + "='true'] [" + attr("data-widget-popup") + "]{width:100%;height:100%;border-radius:0;}[" + attr("data-layout") + "='fullscreen'][" + attr("data-open") + "='true'] [" + attr("data-widget-launcher") + "]{display:none;}}"
    ].join("");
    document.head.appendChild(style);

    document.addEventListener("keydown", function (event) {
      if (event.key !== "Escape") return;
      var order = api().openOrder;
      if (!order.length) return;
      closeWidget(order[order.length - 1]);
    });

    window.addEventListener("message", onMessage);
    var mobile = window.matchMedia("(max-width: 640px)");
    if (mobile.addEventListener) {
      mobile.addEventListener("change", function () { refreshLayouts(); });
    }
  }

  function attr(name) {
    return name;
  }

  function scan() {
    var nodes = document.querySelectorAll("script[data-embed][src*='widget.js']");
    for (var i = 0; i < nodes.length; i += 1) initScript(nodes[i]);
    if (document.currentScript && document.currentScript.getAttribute("data-embed")) {
      initScript(document.currentScript);
    }
  }

  function initScript(script) {
    if (!script || script.getAttribute("data-recording-studio-widget-booted") === "true") return;
    var token = script.getAttribute("data-embed");
    if (!token) return;
    if (document.querySelector("[" + attr("data-recording-studio-widget") + "='" + cssEscape(token) + "']")) {
      script.setAttribute("data-recording-studio-widget-booted", "true");
      return;
    }
    script.setAttribute("data-recording-studio-widget-booted", "true");
    var inline = script.getAttribute("data-config");
    if (inline) {
      try {
        mount(script, JSON.parse(inline));
      } catch (error) {
        return;
      }
      return;
    }
    fetchConfig(script, token).then(function (config) {
      if (config) mount(script, config);
    });
  }

  function fetchConfig(script, token) {
    var scriptUrl;
    try {
      scriptUrl = new URL(script.src, window.location.href);
    } catch (error) {
      return Promise.resolve(null);
    }
    var launcher = scriptUrl.href.replace(/widget\.js(?:\?.*)?$/, "embeds/" + encodeURIComponent(token) + "/launcher");
    return fetch(launcher, { credentials: "omit", headers: { Accept: "application/json" } })
      .then(function (response) { return response.ok ? response.json() : null; })
      .catch(function () { return null; });
  }

  function mount(script, config) {
    if (!config || !config.id || !config.popup_url) return;
    var popupUrl;
    var scriptUrl;
    try {
      popupUrl = new URL(config.popup_url, window.location.href);
      scriptUrl = new URL(script.src, window.location.href);
    } catch (error) {
      return;
    }
    if (popupUrl.origin !== scriptUrl.origin) return;
    if (document.querySelector("[" + attr("data-recording-studio-widget") + "='" + cssEscape(config.id) + "']")) return;

    var widget = document.createElement("div");
    widget.setAttribute("data-recording-studio-widget", config.id);
    widget.setAttribute("data-position", config.position === "bottom-left" ? "bottom-left" : "bottom-right");
    widget.setAttribute("data-open", "false");
    widget.style.setProperty("--rsw-edge", Number(config.edge_spacing || 20) + "px");
    widget.style.setProperty("--rsw-width", Number(config.popup_width || 380) + "px");
    widget.style.setProperty("--rsw-height", Number(config.popup_height || 560) + "px");
    widget.style.setProperty("--rsw-bg", (config.colors && config.colors.background) || "#111827");
    widget.style.setProperty("--rsw-fg", (config.colors && config.colors.foreground) || "#ffffff");

    var popup = document.createElement("div");
    popup.setAttribute("data-widget-popup", "");
    popup.setAttribute("role", "dialog");
    popup.setAttribute("aria-modal", "true");
    popup.hidden = true;
    var popupId = "recording-studio-widget-popup-" + config.id;
    popup.id = popupId;

    var bar = document.createElement("div");
    bar.setAttribute("data-widget-bar", "");
    var title = document.createElement("span");
    title.textContent = config.title || "Chat";
    var close = document.createElement("button");
    close.type = "button";
    close.setAttribute("data-widget-close", "");
    close.textContent = "Close";
    bar.appendChild(title);
    bar.appendChild(close);

    var frame = document.createElement("iframe");
    frame.setAttribute("data-recording-studio-widget-frame", "");
    frame.title = config.title || "Chat";
    frame.setAttribute("sandbox", "allow-scripts allow-forms allow-same-origin");
    frame.referrerPolicy = "origin";
    frame.addEventListener("load", function () {
      if (!frame.src) return;
      var origin = new URL(frame.src, window.location.href).origin;
      frame.contentWindow.postMessage({ source: HOST, type: "ready" }, origin);
    });

    popup.appendChild(bar);
    popup.appendChild(frame);

    var launcher = document.createElement("button");
    launcher.type = "button";
    launcher.setAttribute("data-widget-launcher", "");
    launcher.setAttribute("aria-expanded", "false");
    launcher.setAttribute("aria-controls", popupId);
    launcher.setAttribute("aria-label", config.title || "Chat");
    if (config.icon_url) {
      var icon = document.createElement("img");
      icon.alt = "";
      icon.src = config.icon_url;
      launcher.appendChild(icon);
    } else {
      launcher.appendChild(bubble());
    }

    widget.appendChild(popup);
    widget.appendChild(launcher);
    widget.addEventListener("recording-studio-widget:close", function () { closeWidget(widget); });
    launcher.addEventListener("click", function () {
      if (widget.getAttribute("data-open") === "true") closeWidget(widget);
      else openWidget(widget, frame, popupUrl.href, launcher);
    });
    close.addEventListener("click", function () { closeWidget(widget); });

    var previewRoot = script.getAttribute("data-preview-root");
    var parent = previewRoot ? document.querySelector(previewRoot) : document.body;
    (parent || document.body).appendChild(widget);
    applyLayout(widget);
  }

  function openWidget(widget, frame, src, launcher) {
    if (!frame.getAttribute("src")) frame.src = src;
    widget.setAttribute("data-open", "true");
    var popup = widget.querySelector("[data-widget-popup]");
    if (popup) popup.hidden = false;
    launcher.setAttribute("aria-expanded", "true");
    var order = api().openOrder.filter(function (item) { return item !== widget; });
    order.push(widget);
    api().openOrder = order;
    var close = widget.querySelector("[data-widget-close]");
    if (close) close.focus();
  }

  function closeWidget(widget) {
    if (!widget || widget.getAttribute("data-open") !== "true") return;
    widget.setAttribute("data-open", "false");
    var popup = widget.querySelector("[data-widget-popup]");
    if (popup) popup.hidden = true;
    var launcher = widget.querySelector("[data-widget-launcher]");
    if (launcher) {
      launcher.setAttribute("aria-expanded", "false");
      launcher.focus();
    }
    api().openOrder = api().openOrder.filter(function (item) { return item !== widget; });
  }

  function onMessage(event) {
    var data = event.data;
    if (!data || data.source !== POPUP) return;
    var frames = document.querySelectorAll("[data-recording-studio-widget-frame]");
    var match = null;
    for (var i = 0; i < frames.length; i += 1) {
      if (frames[i].contentWindow === event.source) match = frames[i];
    }
    if (!match || !match.src) return;
    var expected;
    try { expected = new URL(match.src, window.location.href).origin; } catch (error) { return; }
    if (event.origin !== expected) return;
    var widget = match.closest("[data-recording-studio-widget]");
    if (!widget) return;
    if (data.type === "close") closeWidget(widget);
    if (data.type === "resize" && widget.getAttribute("data-layout") === "panel") {
      var height = Number(data.height);
      if (height > 120 && height < 2000) match.style.height = height + "px";
    }
  }

  function refreshLayouts() {
    var widgets = document.querySelectorAll("[data-recording-studio-widget]");
    for (var i = 0; i < widgets.length; i += 1) applyLayout(widgets[i]);
  }

  function applyLayout(widget) {
    var mobile = window.matchMedia("(max-width: 640px)").matches;
    widget.setAttribute("data-layout", mobile ? "fullscreen" : "panel");
  }

  function bubble() {
    var svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("viewBox", "0 0 24 24");
    svg.setAttribute("width", "28");
    svg.setAttribute("height", "28");
    svg.setAttribute("aria-hidden", "true");
    var path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    path.setAttribute("fill", "currentColor");
    path.setAttribute("d", "M4 4h16a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H9l-5 4v-4H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z");
    svg.appendChild(path);
    return svg;
  }

  function cssEscape(value) {
    if (window.CSS && CSS.escape) return CSS.escape(value);
    return String(value).replace(/["\\]/g, "\\$&");
  }

  api();
  scan();
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", scan);
})();
