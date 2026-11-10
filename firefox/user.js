{
  "//": "ShyProject coding profile — Firefox prefs for a laptop on battery.",
  "//1": "Copy to <profile>/user.js, not prefs.js: this file is read at every start.",
  "//2": "Only settings that remove background work; nothing here changes privacy defaults.",

  "// animations and smooth scrolling": "they keep the compositor busy while idle-reading",
  "toolkit.cosmeticAnimations.enabled": false,
  "ui.prefersReducedMotion": 1,
  "general.smoothScroll": false,
  "browser.tabs.loadInBackground": true,

  "// fewer content processes": "4 is enough for a coding session and saves RAM/CPU",
  "dom.ipc.processCount": 4,
  "browser.tabs.unloadOnLowMemory": true,
  "browser.sessionstore.interval": 600000,

  "// no background prefetching or speculation": "each one is a network wakeup",
  "network.prefetch-next": false,
  "network.dns.disablePrefetch": true,
  "network.predictor.enabled": false,
  "browser.urlbar.speculativeConnect.enabled": false,

  "// telemetry, experiments, sponsored content": "all silent background timers",
  "toolkit.telemetry.enabled": false,
  "datareporting.healthreport.uploadEnabled": false,
  "app.shield.optoutstudies.enabled": false,
  "browser.newtabpage.activity-stream.feeds.telemetry": false,
  "browser.newtabpage.activity-stream.telemetry": false,
  "extensions.pocket.enabled": false,
  "browser.newtabpage.activity-stream.showSponsoredTopSites": false,

  "// hardware video decode stays on": "this is the one place the GPU earns its power",
  "media.hardware-video-decoding.enabled": true,
  "gfx.webrender.all": true,

  "// a quiet start": "no default-browser check, blank new tab",
  "browser.shell.checkDefaultBrowser": false,
  "browser.startup.homepage": "about:blank",
  "browser.newtabpage.enabled": false
}
