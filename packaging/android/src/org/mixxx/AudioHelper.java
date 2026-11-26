package org.mixxx;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.os.Build;
import android.util.Log;

import java.util.List;

/// Helpers for the Android audio system used by SoundManager.
public class AudioHelper {
    private static final String TAG = "MixxxAudio";

    /// Android applies the media volume to USB sound cards in software, so a
    /// DJ controller plays at e.g. -26 dB with the volume at half. DJ
    /// controllers have their own master and headphone level knobs, so the
    /// media volume is raised to the maximum while it is routed only to USB.
    /// Returns true if the volume was changed.
    public static boolean maximizeMediaVolumeForUsb(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            // Without getAudioDevicesForAttributes the routing can't be
            // verified, and raising the volume of the speaker could be harmful.
            return false;
        }
        AudioManager audioManager =
                (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        if (audioManager == null) {
            return false;
        }
        AudioAttributes attributes = new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build();
        List<AudioDeviceInfo> devices = audioManager.getAudioDevicesForAttributes(attributes);
        if (devices == null || devices.isEmpty()) {
            return false;
        }
        for (AudioDeviceInfo device : devices) {
            int type = device.getType();
            if (type != AudioDeviceInfo.TYPE_USB_DEVICE
                    && type != AudioDeviceInfo.TYPE_USB_HEADSET
                    && type != AudioDeviceInfo.TYPE_USB_ACCESSORY) {
                Log.i(TAG, "Media is not routed to USB only, keeping the volume");
                return false;
            }
        }
        int max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
        int current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
        if (current >= max) {
            return false;
        }
        try {
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, max, AudioManager.FLAG_SHOW_UI);
        } catch (SecurityException e) {
            // e.g. Do Not Disturb restrictions
            Log.w(TAG, "Unable to change the media volume: " + e.toString());
            return false;
        }
        Log.i(TAG, "Raised the USB media volume from " + current + " to " + max);
        return true;
    }

    // [AI-generated text, Claude (Anthropic) — start]
    /// Cutlab 1.32.2: the headphones connected now (wired, USB-C, Bluetooth),
    /// as "type:name" joined with ";", sorted. PortAudio with Oboe only knows
    /// the outputs there were when the app opened: the app compares this
    /// with the value at the start and offers to restart.
    // [AI-generated text, Claude (Anthropic) — end]
    public static String headphoneOutputs(Context context) {
        AudioManager audioManager =
                (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        if (audioManager == null) {
            return "";
        }
        java.util.ArrayList<String> found = new java.util.ArrayList<>();
        for (AudioDeviceInfo device : audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
            int type = device.getType();
            if (type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES
                    || type == AudioDeviceInfo.TYPE_WIRED_HEADSET
                    || type == AudioDeviceInfo.TYPE_USB_HEADSET
                    || type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
                    || type == AudioDeviceInfo.TYPE_BLE_HEADSET
                    || type == AudioDeviceInfo.TYPE_BLE_SPEAKER) {
                found.add(type + ":" + device.getProductName());
            }
        }
        java.util.Collections.sort(found);
        return String.join(";", found);
    }
}
