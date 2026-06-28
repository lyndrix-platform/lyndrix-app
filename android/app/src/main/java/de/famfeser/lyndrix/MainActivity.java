package de.famfeser.lyndrix;

import android.content.SharedPreferences;
import android.os.Bundle;

import com.getcapacitor.BridgeActivity;
import com.getcapacitor.CapConfig;

/**
 * Capacitor host activity for the Lyndrix shell.
 *
 * <p>This is a REMOTE-LOAD app: the WebView loads the Lyndrix UI from a server origin, and because
 * the UI talks to its backend via same-origin relative {@code /api/...} calls, that origin is also
 * the backend. The origin is runtime-configurable (see {@link BackendSwitcherPlugin}).</p>
 *
 * <p>The Capacitor bridge only binds to the host configured as the bridge's {@code serverUrl}; hosts
 * reached via {@code allowNavigation} or a raw {@code loadUrl} lose the native bridge on Android.
 * So we inject the persisted origin into {@link CapConfig} <em>before</em> the bridge is built, and
 * switching origins is done by persisting the new value and calling {@code recreate()} — never by
 * navigating the WebView.</p>
 */
public class MainActivity extends BridgeActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // Register the custom local plugin before the bridge is created.
        registerPlugin(BackendSwitcherPlugin.class);

        // Resolve the origin. On first run (or after a reset to the picker) nothing is persisted, so
        // we leave serverUrl unset and Capacitor loads the bundled webDir (www/index.html) — the
        // first-run server picker. Once the user picks an origin it is persisted and loaded remotely.
        SharedPreferences prefs = getSharedPreferences(BackendSwitcherPlugin.PREFS_NAME, MODE_PRIVATE);
        String serverUrl = prefs.getString(BackendSwitcherPlugin.KEY_SERVER_URL, null);

        // Override the bridge config BEFORE super.onCreate() — BridgeActivity.onCreate() consumes
        // `this.config` at the end via load(). A fresh Builder is intentional: setting serverUrl here
        // is what lets the chosen origin (and the dev flavor's default) win over the shared
        // assets/capacitor.config.json.
        CapConfig.Builder builder = new CapConfig.Builder(this)
                .setAndroidScheme("https")
                .setBackgroundColor("#0b1220")
                // If the chosen origin can't be reached, fall back to the bundled picker instead of a
                // dead WebView — a native escape hatch to re-select a server without the remote UI.
                .setErrorPath("index.html");
        if (serverUrl != null) {
            builder.setServerUrl(serverUrl);
        }
        this.config = builder.create();

        super.onCreate(savedInstanceState);
    }
}
