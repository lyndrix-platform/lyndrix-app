import type { CapacitorConfig } from '@capacitor/cli';

// Source of truth for the Capacitor shell (replaces the old Bubblewrap twa-manifest.json).
//
// This is a REMOTE-LOAD app: the WebView loads the Lyndrix UI from `server.url`. Because the UI
// talks to its backend via same-origin relative `/api/...` calls, the loaded origin *is* the
// backend — switching the origin switches UI + backend together (no CORS, no auth rework).
//
// `server.url` below is only the COMPILED-IN FALLBACK default. At runtime MainActivity overrides it
// with the user's chosen origin from SharedPreferences (see BackendSwitcherPlugin), and each Gradle
// product flavor supplies its own DEFAULT_SERVER_URL (prod -> mngm…, dev -> ui.dev…).
//
// NOTE: Capacitor logs a "server.url is not recommended for production" warning. That warning is
// about Apple App Store review only — this is an Android sideload / GitHub-Release app, so it does
// not apply. Do not "fix" it by removing server.url.
const config: CapacitorConfig = {
  appId: 'de.famfeser.lyndrix',
  appName: 'Lyndrix',
  webDir: 'www',
  server: {
    url: 'https://mngm.int.fam-feser.de',
    androidScheme: 'https',
    cleartext: false,
  },
  android: {
    backgroundColor: '#0b1220',
  },
};

export default config;
