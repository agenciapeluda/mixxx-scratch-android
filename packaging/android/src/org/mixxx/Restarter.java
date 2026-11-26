package org.mixxx;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Process;

// [AI-generated text, Claude (Anthropic) — start]
/// Cutlab 1.32.0: restarts the app cleanly (after restoring a library).
///
/// Up to 1.31 the app quit through QCoreApplication::quit(), Qt's own exit,
/// which crashes at times in Android's threads (see MainActivity.onDestroy)
/// and showed "Cutlab closed because of an error". This activity runs in its
/// own process (":restart" in the manifest): it ends the process of the app,
/// opens the app again and ends itself.
/// [AI-generated text, Claude (Anthropic) — end]
public class Restarter extends Activity {
    private static final String EXTRA_PID = "pid";

    /// Called from C++ once the settings and the tracks are saved
    public static void restart(final Context context) {
        final Intent intent = new Intent(context, Restarter.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.putExtra(EXTRA_PID, Process.myPid());
        context.startActivity(intent);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        final int pid = getIntent().getIntExtra(EXTRA_PID, -1);
        if (pid > 0 && pid != Process.myPid()) {
            Process.killProcess(pid);
        }
        final Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
            startActivity(launch);
        }
        finish();
        Runtime.getRuntime().exit(0);
    }
}
