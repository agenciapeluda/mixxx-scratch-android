package org.mixxx;

import android.content.ClipData;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import androidx.core.content.FileProvider;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;

/// Cutlab: shares the log files (this run, the one before, crash reports)
/// through the share sheet, to send them by WhatsApp, Drive, mail...
public class LogShare {
    private static final String TAG = "CutlabLogShare";

    /// paths: one per line. Copied first to the app's own folder, which the
    /// file provider can hand out.
    public static boolean share(Context context, String paths) {
        try {
            File dir = new File(context.getExternalFilesDir(null), "shared-logs");
            dir.mkdirs();
            File[] old = dir.listFiles();
            if (old != null) {
                for (File file : old) {
                    file.delete();
                }
            }
            ArrayList<Uri> uris = new ArrayList<>();
            for (String path : paths.split("\n")) {
                File source = new File(path);
                if (!source.isFile()) {
                    continue;
                }
                String name = source.getName();
                if (!name.endsWith(".log") && !name.endsWith(".txt")) {
                    name = name + ".txt";
                }
                File copy = new File(dir, name);
                try (InputStream in = new FileInputStream(source);
                        OutputStream out = new FileOutputStream(copy)) {
                    byte[] buffer = new byte[64 * 1024];
                    int read;
                    while ((read = in.read(buffer)) > 0) {
                        out.write(buffer, 0, read);
                    }
                }
                uris.add(FileProvider.getUriForFile(
                        context, context.getPackageName() + ".qtprovider", copy));
            }
            if (uris.isEmpty()) {
                return false;
            }
            Intent intent = new Intent(Intent.ACTION_SEND_MULTIPLE);
            intent.setType("text/plain");
            intent.putExtra(Intent.EXTRA_SUBJECT, "Cutlab log");
            intent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris);
            ClipData clip = ClipData.newRawUri("Cutlab log", uris.get(0));
            for (int i = 1; i < uris.size(); i++) {
                clip.addItem(new ClipData.Item(uris.get(i)));
            }
            intent.setClipData(clip);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            Intent chooser = Intent.createChooser(intent, "Compartir log de Cutlab");
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION);
            context.startActivity(chooser);
            return true;
        } catch (IOException | RuntimeException e) {
            Log.w(TAG, "Unable to share the log", e);
            return false;
        }
    }
}
