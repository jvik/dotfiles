// user-overrides.js
// Personal overrides on top of arkenfox user.js
// See: https://github.com/arkenfox/user.js/wiki/3.1-Overrides
//
// Run updater.sh after editing this file to regenerate user.js

// Disable AI chatbot (Firefox sidebar)
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.shortcuts", false);
user_pref("browser.ml.chat.shortcuts.longPress", false);

/* [EXAMPLE OVERRIDES - uncomment and adjust as needed]

// Keep your language (arkenfox forces en-US)
user_pref("intl.accept_languages", "nb-NO, nb, no, en-US, en");

// Allow specific sites to use WebGL (arkenfox disables it)
// user_pref("webgl.disabled", false);

// Enable DRM (arkenfox disables it)
// user_pref("media.eme.enabled", true);

*/


user_pref("extensions.pocket.enabled", false); //fully disable pocket
user_pref("identity.fxaccounts.enabled", true); //enable sync
user_pref("places.history.enabled", true); // enable history
// Figma compatibility: requires modern JS engines and WebAssembly.
user_pref("javascript.options.ion", true);
user_pref("javascript.options.asmjs", true);
user_pref("javascript.options.wasm", true);
user_pref("javascript.options.baselinejit", true);
user_pref("dom.webaudio.enabled", true);
user_pref("browser.safebrowsing.downloads.remote.enabled", true);
user_pref("browser.safebrowsing.phishing.enabled", true);
user_pref("browser.safebrowsing.malware.enabled", true);
user_pref("dom.webnotifications.enabled", true); // enable notifications
user_pref("browser.urlbar.suggest.history", true); //suggestions from history
user_pref("browser.urlbar.suggest.openpage", true); // suggestions from open pages
user_pref("browser.urlbar.suggest.topsites", false); //no top sites in the suggestions
user_pref("signon.management.page.breach-alerts.enabled", true);
user_pref("layout.spellcheckDefault", 0); //no spell-check
user_pref("signon.rememberSignons", false); //never ask to save passwords
user_pref("permissions.default.geo", 2); //deny location access
user_pref("geo.enabled", false); //fullly disable location acces
user_pref("media.navigator.enabled", false); //disabled some media features



//Section 2: Re-enabled features
user_pref("keyword.enabled", true); //search from the urlbar
user_pref("browser.startup.page", 0); //Browser starts on the Homepage
user_pref("browser.startup.homepage", "about:home"); //Sets homepage
user_pref("browser.newtabpage.enabled", false); //use default NTP
user_pref("browser.download.useDownloadDir", false); //always download files to the System Download Directory
user_pref("browser.urlbar.suggest.searches", false); //disables search suggestions in the url-bar



//Section 3: Misc changes (mostly personal prefrence)
user_pref("browser.compactmode.show", true); //compact mode is displayed by default
user_pref("browser.uidensity", 1); //enables compact mode by default
user_pref("privacy.spoof_english", 2); //spoofs english by default

// Figma compatibility: keep WebGL enabled.
user_pref("webgl.disabled", false);