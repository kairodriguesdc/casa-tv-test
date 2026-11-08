package app.casa.test;

import android.accessibilityservice.AccessibilityService;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Test 2: does the mic button reach CASA while another app (Netflix, the home screen) is on screen?
 * When it does, this opens CASA Test and starts listening. Every other button passes through untouched.
 * It keeps only the names of the last 12 buttons pressed, on the TV, so the test page can show them.
 */
public class MicWatchService extends AccessibilityService {

    private static final int KEEP = 12;

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        prefs().edit().putBoolean("connected", true).apply();
        Log.i(MainActivity.TAG, "WATCH connected");
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        // Not used: this service only looks at remote buttons.
    }

    @Override
    public void onInterrupt() {
    }

    @Override
    protected boolean onKeyEvent(KeyEvent e) {
        int code = e.getKeyCode();
        boolean down = e.getAction() == KeyEvent.ACTION_DOWN && e.getRepeatCount() == 0;
        if (down) remember(code);

        if (MainActivity.isMicKey(code)) {
            if (down) {
                String when = new SimpleDateFormat("HH:mm:ss", Locale.ROOT).format(new Date());
                SharedPreferences p = prefs();
                p.edit().putInt("micCount", p.getInt("micCount", 0) + 1)
                        .putString("lastMic", KeyEvent.keyCodeToString(code) + " at " + when)
                        .apply();
                Log.i(MainActivity.TAG, "WATCH mic " + KeyEvent.keyCodeToString(code));
                Intent open = new Intent(this, MainActivity.class)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        .putExtra("fromMic", true);
                try {
                    startActivity(open);
                } catch (RuntimeException ex) {
                    Log.w(MainActivity.TAG, "WATCH could not open app: " + ex);
                }
            }
            return true; // CASA takes the mic button
        }
        return false; // every other button behaves as normal
    }

    private void remember(int code) {
        SharedPreferences p = prefs();
        String name = KeyEvent.keyCodeToString(code).replace("KEYCODE_", "");
        String keys = p.getString("keys", "");
        String next = keys.isEmpty() ? name : name + "," + keys;
        String[] parts = next.split(",");
        if (parts.length > KEEP) {
            StringBuilder b = new StringBuilder();
            for (int i = 0; i < KEEP; i++) {
                if (i > 0) b.append(',');
                b.append(parts[i]);
            }
            next = b.toString();
        }
        p.edit().putString("keys", next).apply();
        Log.i(MainActivity.TAG, "WATCH key " + name);
    }

    private SharedPreferences prefs() {
        return getSharedPreferences(MainActivity.PREFS, MODE_PRIVATE);
    }
}
