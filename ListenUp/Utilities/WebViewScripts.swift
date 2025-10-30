//
//  WebViewScripts.swift
//  ListenUp
//
//  Created by S M H  on 18/07/2025.
//

import Foundation
//import WebBrowser
import WebKit

struct WebViewScripts {
    
    static let jsString = """
      // Add playsinline attributes to videos & iframes
      document.querySelectorAll('video, iframe').forEach(el => {
        el.setAttribute('playsinline', '');
        el.setAttribute('webkit-playsinline', '');
      });
    """
    
    static let trackerJS = """
    (function(){
      var lastHref = null;
      var pending = false;

      function postIfChanged(reason){
        var href = location.href;
        if (href === lastHref) return;       // suppress duplicates
        lastHref = href;
        try {
          window.webkit.messageHandlers.pageURL.postMessage({ href: href, reason: reason });
        } catch(_) {}
      }

      function schedule(reason){
        if (pending) return;                 // debounce burst of events
        pending = true;
        setTimeout(function(){
          pending = false;
          postIfChanged(reason);
        }, 120);
      }

      // initial
      postIfChanged("init");

      // history API
      ["pushState","replaceState"].forEach(function(fn){
        var orig = history[fn];
        history[fn] = function(){
          var ret = orig.apply(this, arguments);
          schedule("history:" + fn);
          return ret;
        };
      });

      // browser nav
      window.addEventListener("popstate", function(){ schedule("popstate"); }, true);
      window.addEventListener("hashchange", function(){ schedule("hashchange"); }, true);

      // clicks on anchors (best effort)
      document.addEventListener("click", function(e){
        var a = e.target && e.target.closest && e.target.closest("a[href]");
        if (a) schedule("click");
      }, true);

      // Lightweight fallback: poll every 500ms (optional; comment out if not needed)
      var last = location.href;
      setInterval(function(){
        if (location.href !== last) {
          last = location.href;
          schedule("interval");
        }
      }, 500);
    })();
    """
    
    static let mediaObserverJS = """
    (function () {
      // 🔒 Prevent double-injection
      if (window.__mediaObserverInstalled) return;
      window.__mediaObserverInstalled = true;

      // Track last report per element to suppress repeats
      const lastReport = new WeakMap(); // el -> { src, t, ts }

      function shouldReport(el, src, currentTime) {
        const now = Date.now();
        const prev = lastReport.get(el);
        if (prev && prev.src === src) {
          // ignore if called again within 1s or time change < 0.5s
          if ((now - prev.ts) < 1000 || Math.abs(currentTime - prev.t) < 0.5) return false;
        }
        lastReport.set(el, { src, t: currentTime, ts: now });
        return true;
      }

      function post(type, action, src, title, t) {
        try {
          window.webkit.messageHandlers.mediaEvent.postMessage({ type, action, src, title, currentTime: t });
        } catch (_) {}
      }

      // Keep originals (only once)
      const origVideoPlay = HTMLVideoElement.prototype.play;
      const origAudioPlay = HTMLAudioElement.prototype.play;

      // Patch video.play
      HTMLVideoElement.prototype.play = function () {
        const src = this.currentSrc || this.src || '';
        const title = this.getAttribute("title") || document.title || "Untitled Video";
        if (src && shouldReport(this, src, title, this.currentTime)) {
          post('video', 'play', src, title, this.currentTime);
        }
        return origVideoPlay.apply(this, arguments);
      };

      // Patch audio.play
      HTMLAudioElement.prototype.play = function () {
        const src = this.currentSrc || this.src || '';
        const title = this.getAttribute("title") || document.title || "Untitled Video";
        if (src && shouldReport(this, src, title, this.currentTime)) {
          post('audio', 'play', src, title, this.currentTime);
        }
        return origAudioPlay.apply(this, arguments);
      };

      // (Optional) also signal on real 'playing' event (not just play() calls)
      function onPlaying(e) {
        const el = e.target;
        const tag = el.tagName;
        if (tag !== 'VIDEO' && tag !== 'AUDIO') return;
        const src = el.currentSrc || el.src || '';
        if (src && shouldReport(el, src, el.currentTime)) {
          post(tag.toLowerCase(), 'playing', src, el.currentTime);
        }
      }
      document.addEventListener('playing', onPlaying, true);

      // MutationObserver (optional – just for your logs, no posts)
      try {
        const observer = new MutationObserver(muts => {
          for (const m of muts) {
            for (const n of m.addedNodes) {
              if (n && (n.tagName === 'VIDEO' || n.tagName === 'AUDIO')) {
                // console.log('New media element:', n.tagName);
              }
            }
          }
        });
        observer.observe(document.body || document.documentElement, { childList: true, subtree: true });
      } catch (_) {}
    })();
    """

    // The JS injector
    static let jsUserScript = WKUserScript(
        source: jsString,
      injectionTime: .atDocumentEnd,
      forMainFrameOnly: false
    )

    // Media Observer Injector
    static let mediaScript = WKUserScript(
        source: mediaObserverJS,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: false
    )
    
    static let trackerScript = WKUserScript(
        source: trackerJS,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )

}
