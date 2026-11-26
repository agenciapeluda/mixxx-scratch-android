package org.mixxx;

import android.app.Activity;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.net.Uri;
import android.os.PowerManager;
import android.provider.Settings;
import android.util.Log;
import android.view.Window;
import android.view.WindowManager;

// [AI-generated text, Claude (Anthropic) — start]
/// Cutlab 1.32.0: "Modo show", the phone set for a set.
///
/// Android lets no app turn on flight mode, turn off Wi-Fi or Bluetooth or
/// stop other apps (only system apps can). What an app may do, and this
/// does: Do Not Disturb while Cutlab is open (with the access the user
/// grants once) and back to what it was after; exclusive audio focus, so
/// Spotify, YouTube and the like pause; the screen on and the sustained
/// performance mode where the phone has it. The panels of Internet and
/// Bluetooth open so the user turns them off with one tap.
/// [AI-generated text, Claude (Anthropic) — end]
public final class ShowMode {
    private static final String TAG = "CutlabShowMode";
    private static final String PREFS = "cutlab_show_mode";
    // The Do Not Disturb filter before the show mode, -1 when none is saved
    private static final String KEY_SAVED_FILTER = "saved_filter";

    private static AudioFocusRequest sFocus;

    private ShowMode() {
    }

    public static boolean hasDndAccess(final Context context) {
        final NotificationManager manager = context.getSystemService(NotificationManager.class);
        return manager != null && manager.isNotificationPolicyAccessGranted();
    }

    public static void openDndAccess(final Context context) {
        start(context, new Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS));
    }

    public static boolean ignoresBatteryOptimizations(final Context context) {
        final PowerManager power = context.getSystemService(PowerManager.class);
        return power != null && power.isIgnoringBatteryOptimizations(context.getPackageName());
    }

    public static void requestIgnoreBatteryOptimizations(final Context context) {
        start(context, new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:" + context.getPackageName())));
    }

    public static void openInternetPanel(final Context context) {
        start(context, new Intent(Settings.Panel.ACTION_INTERNET_CONNECTIVITY));
    }

    public static void openBluetoothSettings(final Context context) {
        start(context, new Intent(Settings.ACTION_BLUETOOTH_SETTINGS));
    }

    /// Turns the show mode on or off
    public static void setEnabled(final Context context, final boolean on) {
        try {
            if (on) {
                enableDnd(context);
                requestFocus(context);
            } else {
                restoreDnd(context);
                abandonFocus(context);
            }
            applyWindow(context, on);
        } catch (Exception e) {
            Log.w(TAG, "setEnabled", e);
        }
    }

    /// Do Not Disturb back to what it was, if the show mode changed it
    /// (also after a crash: called at every start with the mode off)
    public static void restoreDnd(final Context context) {
        final SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        final int saved = prefs.getInt(KEY_SAVED_FILTER, -1);
        if (saved == -1) {
            return;
        }
        final NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (manager != null && manager.isNotificationPolicyAccessGranted()) {
            manager.setInterruptionFilter(saved);
        }
        prefs.edit().remove(KEY_SAVED_FILTER).apply();
    }

    /// When the app closes
    public static void release(final Context context) {
        try {
            restoreDnd(context);
            abandonFocus(context);
        } catch (Exception e) {
            Log.w(TAG, "release", e);
        }
    }

    private static void enableDnd(final Context context) {
        final NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (manager == null || !manager.isNotificationPolicyAccessGranted()) {
            return;
        }
        final SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        if (prefs.getInt(KEY_SAVED_FILTER, -1) == -1) {
            prefs.edit().putInt(KEY_SAVED_FILTER, manager.getCurrentInterruptionFilter()).apply();
        }
        // Priority only: calls and notifications silent, media (Cutlab)
        // still plays. "Total silence" would mute the music too.
        manager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY);
    }

    private static void requestFocus(final Context context) {
        if (sFocus != null) {
            return;
        }
        final AudioManager audio = context.getSystemService(AudioManager.class);
        if (audio == null) {
            return;
        }
        sFocus = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(new AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build())
                // Cutlab keeps playing whatever happens to the focus
                .setOnAudioFocusChangeListener(change -> {})
                .build();
        audio.requestAudioFocus(sFocus);
    }

    private static void abandonFocus(final Context context) {
        if (sFocus == null) {
            return;
        }
        final AudioManager audio = context.getSystemService(AudioManager.class);
        if (audio != null) {
            audio.abandonAudioFocusRequest(sFocus);
        }
        sFocus = null;
    }

    private static void applyWindow(final Context context, final boolean on) {
        if (!(context instanceof Activity)) {
            return;
        }
        final Activity activity = (Activity) context;
        activity.runOnUiThread(() -> {
            final Window window = activity.getWindow();
            if (window == null) {
                return;
            }
            if (on) {
                // Off again is left to the screensaver setting of the app
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            }
            final PowerManager power = activity.getSystemService(PowerManager.class);
            if (power != null && power.isSustainedPerformanceModeSupported()) {
                window.setSustainedPerformanceMode(on);
            }
        });
    }

    private static void start(final Context context, final Intent intent) {
        try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } catch (Exception e) {
            Log.w(TAG, "start " + intent.getAction(), e);
        }
    }
}
