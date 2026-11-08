package app.casa.test;

import android.Manifest;
import android.app.Activity;
import android.app.ActivityManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.provider.Settings;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.util.Log;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;

/**
 * CASA Test: one full-screen web page (assets/index.html) plus the native pieces a web page can't do on its own:
 * catching remote buttons, Android speech recognition and device facts. Results are logged under the tag "CasaTest".
 */
public class MainActivity extends Activity {

    static final String TAG = "CasaTest";
    static final String PREFS = "casa_test";
    private static final int REQ_MIC = 7;

    private WebView web;
    private SpeechRecognizer recognizer;
    private boolean pageReady = false;
    private boolean pendingMicOpen = false;
    private boolean listening = false;
    private long lastLevelSent = 0;

    /** Remote keys that usually mean "voice" on Android TV. The key log shows if this TV uses another one. */
    static boolean isMicKey(int code) {
        return code == KeyEvent.KEYCODE_SEARCH
                || code == KeyEvent.KEYCODE_VOICE_ASSIST
                || code == KeyEvent.KEYCODE_ASSIST;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        web = new WebView(this);
        web.setBackgroundColor(Color.BLACK);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        web.addJavascriptInterface(new Bridge(), "Android");
        web.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView view, String url) {
                pageReady = true;
                if (pendingMicOpen) {
                    pendingMicOpen = false;
                    openedByMic();
                }
            }
        });
        setContentView(web);
        web.loadUrl("file:///android_asset/index.html");
        handleIntent(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIntent(intent);
    }

    private void handleIntent(Intent intent) {
        if (intent != null && intent.getBooleanExtra("fromMic", false)) {
            intent.removeExtra("fromMic");
            if (pageReady) openedByMic(); else pendingMicOpen = true;
        }
    }

    private void openedByMic() {
        js("casa.onOpenedByMic()");
        startVoice();
    }

    @Override
    protected void onResume() {
        super.onResume();
        js("casa.refreshInfo()");
    }

    // ---------- Remote buttons ----------

    @Override
    public boolean dispatchKeyEvent(KeyEvent e) {
        int code = e.getKeyCode();
        if (e.getAction() == KeyEvent.ACTION_DOWN) {
            if (e.getRepeatCount() == 0 || e.getRepeatCount() == 1) sendKey(e);
        }
        if (isMicKey(code)) {
            if (e.getAction() == KeyEvent.ACTION_DOWN && e.getRepeatCount() == 0) startVoice();
            return true; // keep it away from Google Assistant while this app is open
        }
        if (code == KeyEvent.KEYCODE_BACK && listening) {
            if (e.getAction() == KeyEvent.ACTION_UP) stopVoice();
            return true;
        }
        return super.dispatchKeyEvent(e);
    }

    private void sendKey(KeyEvent e) {
        try {
            JSONObject o = new JSONObject();
            o.put("code", e.getKeyCode());
            o.put("name", KeyEvent.keyCodeToString(e.getKeyCode()));
            o.put("scan", e.getScanCode());
            o.put("repeat", e.getRepeatCount());
            o.put("mic", isMicKey(e.getKeyCode()));
            InputDevice d = e.getDevice();
            o.put("device", d != null ? d.getName() : "unknown");
            js("casa.onKey(" + o + ")");
            if (e.getRepeatCount() == 0) Log.i(TAG, "KEY " + o);
        } catch (JSONException ignored) {
        }
    }

    // ---------- Voice ----------

    private void startVoice() {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            voice("asking", "Allow the microphone on the TV, then press the mic button again.", null);
            requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO}, REQ_MIC);
            return;
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            voice("unavailable", "This TV has no speech recognition available to apps.", null);
            return;
        }
        if (recognizer == null) {
            recognizer = SpeechRecognizer.createSpeechRecognizer(this);
            recognizer.setRecognitionListener(new Listener());
        } else {
            recognizer.cancel();
        }
        Intent i = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
        i.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, getPackageName());
        listening = true;
        voice("starting", "Starting the microphone…", null);
        recognizer.startListening(i);
    }

    private void stopVoice() {
        listening = false;
        if (recognizer != null) recognizer.cancel();
        voice("stopped", "Stopped.", null);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] results) {
        super.onRequestPermissionsResult(requestCode, permissions, results);
        if (requestCode != REQ_MIC) return;
        if (results.length > 0 && results[0] == PackageManager.PERMISSION_GRANTED) startVoice();
        else voice("denied", "Microphone permission was not given.", null);
        js("casa.refreshInfo()");
    }

    private void voice(String status, String message, String text) {
        try {
            JSONObject o = new JSONObject();
            o.put("status", status);
            o.put("message", message);
            if (text != null) o.put("text", text);
            js("casa.onVoice(" + o + ")");
            Log.i(TAG, "VOICE " + o);
        } catch (JSONException ignored) {
        }
    }

    private class Listener implements RecognitionListener {
        @Override public void onReadyForSpeech(Bundle params) { voice("ready", "Listening. Say something.", null); }
        @Override public void onBeginningOfSpeech() { voice("hearing", "Hearing you…", null); }
        @Override public void onRmsChanged(float rmsdB) {
            long now = SystemClock.uptimeMillis();
            if (now - lastLevelSent < 120) return;
            lastLevelSent = now;
            js("casa.onLevel(" + rmsdB + ")");
        }
        @Override public void onBufferReceived(byte[] buffer) { }
        @Override public void onEndOfSpeech() { voice("thinking", "Got it, recognising…", null); }
        @Override public void onError(int error) {
            listening = false;
            voice("error", errorName(error), null);
        }
        @Override public void onResults(Bundle results) {
            listening = false;
            voice("done", "Heard you.", first(results));
        }
        @Override public void onPartialResults(Bundle partial) {
            String t = first(partial);
            if (t != null && !t.isEmpty()) voice("partial", "Hearing you…", t);
        }
        @Override public void onEvent(int eventType, Bundle params) { }
    }

    private static String first(Bundle b) {
        if (b == null) return null;
        ArrayList<String> list = b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        return (list == null || list.isEmpty()) ? null : list.get(0);
    }

    private static String errorName(int e) {
        switch (e) {
            case SpeechRecognizer.ERROR_AUDIO: return "Audio error: the TV couldn't open a microphone.";
            case SpeechRecognizer.ERROR_CLIENT: return "Client error.";
            case SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS: return "No microphone permission.";
            case SpeechRecognizer.ERROR_NETWORK: return "Network error.";
            case SpeechRecognizer.ERROR_NETWORK_TIMEOUT: return "Network timeout.";
            case SpeechRecognizer.ERROR_NO_MATCH: return "Heard nothing it could understand.";
            case SpeechRecognizer.ERROR_RECOGNIZER_BUSY: return "Speech recognition is busy.";
            case SpeechRecognizer.ERROR_SERVER: return "Speech server error.";
            case SpeechRecognizer.ERROR_SPEECH_TIMEOUT: return "No speech heard (timed out).";
            default: return "Error " + e + ".";
        }
    }

    // ---------- Device facts ----------

    private String info() {
        JSONObject o = new JSONObject();
        try {
            o.put("model", Build.MANUFACTURER + " " + Build.MODEL);
            o.put("android", Build.VERSION.RELEASE + " (API " + Build.VERSION.SDK_INT + ")");
            PackageInfo wv = WebView.getCurrentWebViewPackage();
            o.put("webview", wv != null ? wv.packageName + " " + wv.versionName : "unknown");
            ActivityManager am = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
            ActivityManager.MemoryInfo mi = new ActivityManager.MemoryInfo();
            am.getMemoryInfo(mi);
            o.put("ramTotalMb", mi.totalMem / (1024 * 1024));
            o.put("ramFreeMb", mi.availMem / (1024 * 1024));
            o.put("micPermission", checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED);
            o.put("speechAvailable", SpeechRecognizer.isRecognitionAvailable(this));
            o.put("watchEnabled", watchEnabled());
            SharedPreferences p = getSharedPreferences(PREFS, MODE_PRIVATE);
            o.put("watchConnected", p.getBoolean("connected", false));
            o.put("watchMicCount", p.getInt("micCount", 0));
            o.put("watchLastMic", p.getString("lastMic", ""));
            o.put("watchKeys", p.getString("keys", ""));
        } catch (JSONException ignored) {
        }
        return o.toString();
    }

    private boolean watchEnabled() {
        String list = Settings.Secure.getString(getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        if (list == null) return false;
        String me = new ComponentName(this, MicWatchService.class).flattenToString();
        String meShort = new ComponentName(this, MicWatchService.class).flattenToShortString();
        for (String s : list.split(":")) {
            if (s.equalsIgnoreCase(me) || s.equalsIgnoreCase(meShort)) return true;
        }
        return false;
    }

    // ---------- Page bridge ----------

    private void js(final String code) {
        if (web == null) return;
        runOnUiThread(() -> {
            if (pageReady && web != null) web.evaluateJavascript("window.casa && " + code, null);
        });
    }

    private class Bridge {
        @JavascriptInterface public String info() { return MainActivity.this.info(); }
        @JavascriptInterface public void startVoice() { runOnUiThread(MainActivity.this::startVoice); }
        @JavascriptInterface public void stopVoice() { runOnUiThread(MainActivity.this::stopVoice); }
        @JavascriptInterface public void report(String json) { Log.i(TAG, "RESULT " + json); }
        @JavascriptInterface public void log(String line) { Log.i(TAG, line); }
        @JavascriptInterface public void clearWatch() {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                    .putInt("micCount", 0).putString("lastMic", "").putString("keys", "").apply();
        }
        @JavascriptInterface public void exit() { runOnUiThread(MainActivity.this::finish); }
    }

    @Override
    protected void onDestroy() {
        if (recognizer != null) {
            recognizer.destroy();
            recognizer = null;
        }
        if (web != null) {
            web.destroy();
            web = null;
        }
        super.onDestroy();
    }
}
