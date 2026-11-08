# CASA Test: notes for Claude

A temporary Android TV app that answers four questions before CASA is built, on the user's Xiaomi TV (L55M7-7AEU, Mi TV P1E 55", Android TV, about 2 GB RAM):

1. Does the remote's mic button reach an app while it is open?
2. Can Android speech recognition hear the user through the remote?
3. Can a small helper catch the mic button while another app is on screen, and bring CASA up?
4. Does CASA's frosted-glass design run smoothly in the TV's web view?

Package: `app.casa.test`. Plain Java, no libraries. Everything stays on the TV; results go to the TV's log under the tag `CasaTest`.

The TV is wired by Ethernet (its Wi-Fi is broken), on the same router as the user's Mac. Free My TV is installed on it and must not be touched.

## On Windows

The steps below work on Windows too. Differences:

- **Tools:** install a JDK 17+ with `winget install Microsoft.OpenJDK.17` (or Temurin). For the Android SDK, download the "command-line tools only" zip for Windows from developer.android.com, unpack it to `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest`, then run `sdkmanager.bat "platforms;android-34" "build-tools;34.0.0" "platform-tools"`. Gradle: `winget install Gradle.Gradle`, or a portable Gradle zip.
- **Paths:** in `local.properties`, escape backslashes: `sdk.dir=C\:\\Users\\<name>\\AppData\\Local\\Android\\Sdk`. Use `adb.exe` from `<sdk>\platform-tools` if `adb` isn't on PATH.
- **Build:** `gradlew.bat assembleDebug` (or `gradle assembleDebug`).
- **Results in PowerShell:** `adb -s <IP>:5555 logcat -d -s CasaTest | Select-String RESULT | Select-Object -Last 1` instead of `grep`/`tail`.
- **Quoting:** the `settings put` command in step 6 works as written in PowerShell, with the outer double quotes and inner single quotes.
- **New computer, new prompt:** the TV asks to allow debugging once per computer. Tell the user to accept it on the TV (tick Always allow).
- If Windows asks whether to allow `adb` through the firewall, private networks are enough.

## When the user says "install CASA Test on my TV at <IP>"

1. **Tools.** Needs JDK 17 or newer, the Android SDK (platform 34, build-tools 34, platform-tools) and Gradle 8.7 or newer. Check what is installed and install only what is missing (on macOS: Homebrew `temurin` and `android-commandlinetools`, then `sdkmanager "platforms;android-34" "build-tools;34.0.0" "platform-tools"`). Write `local.properties` with `sdk.dir=<path>`. There is no Gradle wrapper in the folder: create one with `gradle wrapper --gradle-version 8.7`, or build with an installed `gradle` directly.
2. **Build.** `./gradlew assembleDebug` → `app/build/outputs/apk/debug/app-debug.apk`.
3. **Connect.** `adb connect <IP>:5555`. If the TV asks to allow debugging, tell the user to accept it on the TV (tick Always allow).
4. **Install.** `adb -s <IP>:5555 install -r app/build/outputs/apk/debug/app-debug.apk`
5. **Allow the microphone.** `adb -s <IP>:5555 shell pm grant app.casa.test android.permission.RECORD_AUDIO`
6. **Switch on the test-3 helper, keeping anything already there.**
   - Save the current values first, into `.casa-backup` in this folder:
     `adb -s <IP>:5555 shell settings get secure enabled_accessibility_services` and
     `adb -s <IP>:5555 shell settings get secure accessibility_enabled`
   - If the first value is `null` or empty, the new value is `app.casa.test/.MicWatchService`. Otherwise it is the old value plus `:app.casa.test/.MicWatchService`. **Never drop existing entries.**
   - `adb -s <IP>:5555 shell "settings put secure enabled_accessibility_services '<new value>'"` then `adb -s <IP>:5555 shell settings put secure accessibility_enabled 1`
   - Tell the user in one line: while the helper is on, the mic button opens CASA Test instead of Google Assistant, until cleanup.
7. **Open it.** `adb -s <IP>:5555 shell am start -n app.casa.test/.MainActivity`
8. **Tell the user what to do on the TV**, in plain words:
   - Test 1: press the mic button, then hold it for a second.
   - Test 2: press the mic button (or Start listening) and say "add a note: buy milk".
   - Test 3: press Home, open any app, then press the mic button. CASA Test should come back and listen.
   - Test 4: select Run smoothness test and wait 20 seconds.
   Each card turns green, amber or red. Results are saved as they go.

## Reading the results

`adb -s <IP>:5555 logcat -d -s CasaTest | grep RESULT | tail -1` prints the latest results as JSON. Explain each in one line, with what it means for CASA:

- `micInApp` set → the mic button can open CASA's assistant while CASA is open. Null → this TV sends the mic button straight to Google; use another button or the phone. The `keys` lines (`KEY {...}`) in the log show what every button sends, useful if the mic uses an unusual code.
- `micLongPress` true → short and long press can do different things (for example short = CASA, long = Google).
- `voice.ok` true with `text` → speech through the remote works. `voice.error` → read the message; "Audio error" usually means the remote mic is reserved for Google, so CASA voice should come from the phone. `heardSound` true with an error means audio arrived but recognition failed.
- `micAnywhere.caught` > 0 and `openedByMic` true → the mic button can bring up CASA from any screen. `helperOn` true but `caught` 0 while `keysSeen` lists other buttons → the TV keeps the mic button for itself.
- `perf.liveGlass.fps` / `perf.lightGlass.fps`: 50+ smooth, 30–49 usable, under 30 choppy. If live is low but light is fine, CASA uses the light glass (pre-blurred background), which looks the same at rest.
- `device`: model, Android version, web engine version, RAM. An old web engine (below Chromium 76) can't draw live blur at all; suggest updating Android System WebView from the Play Store.

## Cleanup (always offer it when the user is done)

1. Restore the two settings from `.casa-backup`: if the saved `enabled_accessibility_services` was `null` or empty, run `adb -s <IP>:5555 shell settings delete secure enabled_accessibility_services`; otherwise put the saved value back exactly. Put `accessibility_enabled` back to its saved value.
2. `adb -s <IP>:5555 uninstall app.casa.test`
3. Confirm the mic button opens Google Assistant again.

Change nothing else on the TV. Don't touch Free My TV or its settings.
