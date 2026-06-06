# Focus Pomodoro 🍅

A brutalist, strict-lockdown Pomodoro focus timer built with Flutter and Native Android. 

This app is designed for deep focus. Once a focus session starts, it takes over your device, blocks internet access, and prevents you from mindlessly scrolling. It forces you to stick to your focus session!

## Features

- **Strict Android Lockdown**: Uses Android Device Policy Manager and System Alerts to prevent you from using other apps during a focus session.
- **VPN Blocking**: Automatically blocks internet access during the focus session so you can't get distracted by notifications or web browsing.
- **Home Screen Widgets**: Includes a standard widget and a 1x1 quick-launch widget to start a focus session directly from your Android home screen.
- **Emergency Dialer**: You can still access the phone dialer from the lockdown screen in case of emergencies, with a strict 15-second timeout to prevent abuse.
- **Gen-Z Aesthetics**: Beautiful, brutalist dark-mode UI with a custom dial picker.

## Download & Install

You can download the pre-compiled Android APK directly from the **[Releases page](https://github.com/ChintalaNavaneeth/focus-pomodoro/releases)**.

When downloading, pick the APK that matches your phone's architecture:
- **`arm64-v8a`**: Download this for almost all modern Android phones (built 2016 or newer).
- **`armeabi-v7a`**: Download this only for much older or very low-end Android devices.
- **`x86_64`**: Download this if you are running the app on a PC emulator (like Android Studio Emulator).

If you are unsure, just try installing the `arm64-v8a` version first! If your phone isn't compatible, Android will simply tell you the app didn't install, and you can try the `armeabi-v7a` version instead.

## How to Run Locally

1. Clone the repository.
2. Make sure you have the Flutter SDK installed.
3. Run `flutter pub get` to install dependencies.
4. Run the app on a physical Android device (emulators might not support all lockdown features):
   ```bash
   flutter run
   ```

### Building the APK locally

If you want to build the APK files yourself for production, run:
```bash
flutter build apk --split-per-abi
```
The compiled APKs will be generated in the following folder:
`build/app/outputs/flutter-apk/`

## FAQ

### Why does it not support iPhones?

While Flutter allows you to write code that runs on both Android and iOS, the **"strict lockdown" features** built into this app are physically impossible to implement on an iPhone without jailbreaking it. Apple enforces a very strict "sandbox" for iOS apps to prioritize user security and privacy:

1. **No "Draw Over Other Apps" (Overlays):** On Android, we use a special permission (`SYSTEM_ALERT_WINDOW`) to draw the black lockdown timer on top of the entire phone system. iOS entirely forbids apps from drawing over the home screen or other apps.
2. **No Device Administration:** We use Android's Device Policy Manager to forcefully turn off your screen and lock your device. Apple does not allow third-party apps to have admin control over the device.
3. **Cannot Block Home Swipe:** Apple guarantees that a user can always swipe up from the bottom to go home and exit an app. There is no API on iOS to intercept or block the home gesture.
4. **Restricted Screen Time API:** The closest thing iOS has is the Screen Time API, but it doesn't allow for a brutalist "full device takeover" where the screen is completely locked out.

In short, Android treats your phone more like a PC where you can grant an app deep system-level control if you want to. iOS treats your phone like a closed ecosystem where the system always remains in control.