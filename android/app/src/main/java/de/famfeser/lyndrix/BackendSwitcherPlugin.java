package de.famfeser.lyndrix;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * Bridge surface for choosing which Lyndrix instance the app talks to at runtime.
 *
 * <p>The JS side ({@code lyndrix-ui/src/lib/nativeBridge.ts}) calls these methods from the
 * native-only settings tab. Switching the origin persists the new value and recreates the Activity
 * so {@link MainActivity#onCreate} rebuilds the bridge against the new host (the only Android-safe
 * way to move the bridge — see the class doc on {@link MainActivity}).</p>
 */
@CapacitorPlugin(name = "BackendSwitcher")
public class BackendSwitcherPlugin extends Plugin {

    public static final String PREFS_NAME = "lyndrix";
    public static final String KEY_SERVER_URL = "serverUrl";

    private SharedPreferences prefs() {
        return getContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    /** Returns the active origin, the flavor default, and whether a user override is in effect. */
    @PluginMethod
    public void getServerUrl(PluginCall call) {
        String def = BuildConfig.DEFAULT_SERVER_URL;
        String current = prefs().getString(KEY_SERVER_URL, def);
        JSObject ret = new JSObject();
        ret.put("url", current);
        ret.put("default", def);
        ret.put("isCustom", !current.equals(def));
        call.resolve(ret);
    }

    /** Persists a new https origin and recreates the Activity to rebind the bridge to it. */
    @PluginMethod
    public void setServerUrl(PluginCall call) {
        String url = call.getString("url");
        if (url == null || url.trim().isEmpty()) {
            call.reject("url is required");
            return;
        }
        url = url.trim();
        if (!isValidHttpsUrl(url)) {
            call.reject("url must be a valid https:// origin");
            return;
        }
        prefs().edit().putString(KEY_SERVER_URL, url).commit();
        call.resolve();
        recreateActivity();
    }

    /** Sets the origin back to the flavor default and reloads (does not return to the picker). */
    @PluginMethod
    public void resetServerUrl(PluginCall call) {
        prefs().edit().putString(KEY_SERVER_URL, BuildConfig.DEFAULT_SERVER_URL).commit();
        JSObject ret = new JSObject();
        ret.put("url", BuildConfig.DEFAULT_SERVER_URL);
        call.resolve(ret);
        recreateActivity();
    }

    /** App identity/version for display in the native settings tab. */
    @PluginMethod
    public void getInfo(PluginCall call) {
        JSObject ret = new JSObject();
        try {
            Context ctx = getContext();
            PackageInfo pi = ctx.getPackageManager().getPackageInfo(ctx.getPackageName(), 0);
            long versionCode = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
                    ? pi.getLongVersionCode()
                    : pi.versionCode;
            ret.put("packageName", ctx.getPackageName());
            ret.put("versionName", pi.versionName);
            ret.put("versionCode", versionCode);
        } catch (PackageManager.NameNotFoundException e) {
            call.reject("Unable to read package info", e);
            return;
        }
        call.resolve(ret);
    }

    private boolean isValidHttpsUrl(String url) {
        try {
            Uri uri = Uri.parse(url);
            return "https".equalsIgnoreCase(uri.getScheme())
                    && uri.getHost() != null
                    && !uri.getHost().isEmpty();
        } catch (Exception e) {
            return false;
        }
    }

    private void recreateActivity() {
        if (getActivity() != null) {
            getActivity().runOnUiThread(() -> getActivity().recreate());
        }
    }
}
