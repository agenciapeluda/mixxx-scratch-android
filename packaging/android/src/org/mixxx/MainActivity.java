package org.mixxx;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.usb.UsbManager;
import android.os.Build;
import android.os.Bundle;
import android.os.PowerManager;
import android.os.Process;
import android.view.Display;
import android.view.WindowManager;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import org.qtproject.qt.android.QtActivityBase;

public class MainActivity extends QtActivityBase {
    private final BroadcastReceiver mUsbHotplugReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            UsbPermission.notifyDevicesChanged();
        }
    };

    // Cutlab: the screen at its highest refresh rate while the app is open
    // (120 Hz on most phones), 60 Hz in battery saver. Phones with an
    // adaptive rate (Samsung and others) otherwise change it on their own
    // while a track plays, and the waveforms judder.
    private final BroadcastReceiver mPowerSaveReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            applyRefreshRate();
        }
    };

    private void applyRefreshRate() {
        try {
            final Display display = getWindow().getDecorView().getDisplay() != null
                    ? getWindow().getDecorView().getDisplay()
                    : getWindowManager().getDefaultDisplay();
            if (display == null) {
                return;
            }
            final PowerManager power = (PowerManager) getSystemService(Context.POWER_SERVICE);
            final boolean saving = power != null && power.isPowerSaveMode();
            final Display.Mode current = display.getMode();
            Display.Mode best = null;
            for (Display.Mode mode : display.getSupportedModes()) {
                if (mode.getPhysicalWidth() != current.getPhysicalWidth()
                        || mode.getPhysicalHeight() != current.getPhysicalHeight()) {
                    continue;
                }
                final float rate = mode.getRefreshRate();
                if (saving) {
                    // The mode closest to 60 Hz
                    if (best == null || Math.abs(rate - 60f) < Math.abs(best.getRefreshRate() - 60f)) {
                        best = mode;
                    }
                } else if (best == null || rate > best.getRefreshRate()) {
                    best = mode;
                }
            }
            if (best == null) {
                return;
            }
            WindowManager.LayoutParams lp = getWindow().getAttributes();
            if (lp.preferredDisplayModeId != best.getModeId()
                    || lp.preferredRefreshRate != best.getRefreshRate()) {
                lp.preferredDisplayModeId = best.getModeId();
                lp.preferredRefreshRate = best.getRefreshRate();
                getWindow().setAttributes(lp);
            }
        } catch (RuntimeException e) {
            // Keep the system's choice
        }
    }

    @Override
    public void onResume() {
        super.onResume();
        applyRefreshRate();
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            getWindow().setPreferMinimalPostProcessing(true);
        }

        // Disable drawing over cutout - isn't working
        WindowManager.LayoutParams lp = this.getWindow().getAttributes();
        lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_NEVER;
        this.getWindow().setAttributes(lp);

        // Disable system and navigation bar to prevent accidental back or app switch
        WindowInsetsControllerCompat windowInsetsController =
            WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
        windowInsetsController.setSystemBarsBehavior(
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        windowInsetsController.hide(WindowInsetsCompat.Type.navigationBars());

        Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_DISPLAY);

        // USB_DEVICE_ATTACHED is only delivered to the activity through
        // onNewIntent, but USB_DEVICE_DETACHED needs a receiver. Both are
        // protected system broadcasts, which also reach receivers that other
        // apps can't send to.
        IntentFilter usbFilter = new IntentFilter();
        usbFilter.addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED);
        usbFilter.addAction(UsbManager.ACTION_USB_DEVICE_DETACHED);
        registerReceiver(mUsbHotplugReceiver, usbFilter, Context.RECEIVER_NOT_EXPORTED);

        MidiHelper.init(this);

        registerReceiver(mPowerSaveReceiver,
                new IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED),
                Context.RECEIVER_NOT_EXPORTED);
        applyRefreshRate();
    }

    /// Saves the settings and the loaded tracks on the main thread of Mixxx,
    /// waits for it at most a few seconds
    private static native void saveBeforeExit();

    @Override
    public void onDestroy() {
        try {
            unregisterReceiver(mUsbHotplugReceiver);
        } catch (IllegalArgumentException e) {
            // Receiver was not registered
        }
        try {
            unregisterReceiver(mPowerSaveReceiver);
        } catch (IllegalArgumentException e) {
            // Receiver was not registered
        }
        if (isFinishing()) {
            // Qt ends the process with System.exit() while the threads of
            // Mixxx and Android are still running, which crashes in them at
            // times (e.g. in Android's hwui threads). Save what Mixxx has to
            // keep and end the process at once instead.
            try {
                saveBeforeExit();
            } catch (UnsatisfiedLinkError e) {
                // The native library isn't loaded (yet)
            }
            Process.killProcess(Process.myPid());
        }
        super.onDestroy();
    }

    @Override
    protected void onNewIntent(android.content.Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        if (UsbManager.ACTION_USB_DEVICE_ATTACHED.equals(intent.getAction())) {
            UsbPermission.notifyDevicesChanged();
        }
    }
}
