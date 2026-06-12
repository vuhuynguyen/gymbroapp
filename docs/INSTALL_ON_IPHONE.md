# Installing GymBro on a Personal iPhone

How to side-load the GymBro Flutter app onto your own iPhone for personal use — no App Store, no
TestFlight. Covers the first (cabled) install, enabling **wireless installs**, and the recurring
**7-day re-sign**.

> This is a free-Apple-ID side-load. The app points at the **live** backend
> (`https://gymbro.ddns.net`) via `config/prod.json`, so no local API is needed on the phone.

---

## TL;DR (recurring install, after first-time setup is done)

```bash
cd gymbroapp
flutter devices                          # confirm the iPhone shows (wireless = no cable needed)
flutter run --release \
  --dart-define-from-file=config/prod.json \
  -d <device-id>                         # e.g. 00008110-001874C80221801E
```

If the app was installed >7 days ago it will have stopped launching — just re-run the command above
to refresh the signature.

---

## Prerequisites (one-time, already satisfied on this machine)

| Tool | Verified version | Check |
|---|---|---|
| Flutter | 3.44 (Dart 3.12) | `flutter --version` |
| Xcode | 26.5 | `xcodebuild -version` |
| CocoaPods | installed | `pod --version` |
| Apple ID | free personal account | added in Xcode → Settings → Accounts |

App identity (set in `ios/Runner.xcodeproj`):
- **Bundle ID:** `com.vnguyen.gymbroapp` (made unique for the personal signing team)
- **Signing:** Automatic, Development Team `86Y8ZLZ2M6`

---

## First-time setup (cabled)

### 1. Configure signing (one time, in Xcode)

```bash
open ios/Runner.xcworkspace
```

- Select the **Runner** target → **Signing & Capabilities**.
- Check **Automatically manage signing**.
- **Team** → your personal Apple ID team. (If the bundle ID is "not available", change it to something
  unique like `com.<you>.gymbroapp`.)

### 2. Plug the iPhone in & trust the Mac

- Connect via a **data-capable** USB cable.
- Unlock the phone → tap **Trust This Computer** → enter passcode.
- Verify it's seen:
  ```bash
  flutter devices            # the iPhone should appear as an ios "mobile" device
  ```

### 3. Enable Developer Mode (appears only AFTER a build attempt)

Developer Mode is **hidden** until Xcode tries to install a build. So run the install once — it will
fail with "enable Developer Mode" — then:

- iPhone → **Settings → Privacy & Security → Developer Mode** → **On**.
- Restart the phone when prompted; after reboot, unlock → **Turn On** → passcode.

### 4. Build & install

```bash
flutter run --release --dart-define-from-file=config/prod.json -d <device-id>
```

First build is slow (~3–4 min: pod install + Xcode compile). The app gets **installed** even if the
auto-launch step reports `Could not run … Runner.app` — that error just means the cert isn't trusted
yet (next step).

### 5. Trust the developer certificate (first install only)

The app icon is on the home screen but won't open until you trust the cert:

- iPhone → **Settings → General → VPN & Device Management** → under **Developer App**, tap your Apple
  ID entry → **Trust** → confirm.
- Tap the **GymBro** icon → it opens to the login screen. Done.

---

## Wireless installs (no cable after one-time pairing)

On **Xcode 16+ / iOS 17+** (this setup) wireless works through Apple's **CoreDevice** pairing — there
is **no "Connect via network" checkbox** anymore (the old Devices-window toggle and the right-click
menu item are both gone). Once the phone has been paired over USB once, it's reachable over Wi-Fi
automatically. `devicectl` shows it as `Autunna.coredevice.local`.

To use it:

1. **Unplug the cable.**
2. Keep the phone **unlocked** and on the **same Wi-Fi** as the Mac.
3. Verify it's reachable over the air:
   ```bash
   flutter devices            # iPhone listed with a "wireless" tag, no cable attached
   xcrun devicectl list devices | grep -i autunna   # State: connected
   ```

From then on, every `flutter run --release --dart-define-from-file=config/prod.json -d <device-id>`
installs over the air. (Wireless builds are a bit slower than cabled.)

> If the phone doesn't appear wirelessly: unlock it, confirm same Wi-Fi, and re-plug the cable once to
> re-establish the CoreDevice pairing — it then persists over Wi-Fi again.

---

## The 7-day limit (free Apple ID)

A free personal signing cert is valid for **7 days**. After that the app refuses to launch ("could
not verify app"). There is nothing to fix on the phone — just **re-run the install** to mint a fresh
signature:

```bash
cd gymbroapp
flutter run --release --dart-define-from-file=config/prod.json -d <device-id>
```

Your data is unaffected — it lives on the server, not in the app. To escape the 7-day cycle entirely,
enroll in the paid **Apple Developer Program** ($99/yr), which extends signing to 1 year and unlocks
TestFlight for sharing with others.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Could not run … Runner.app` right after install | Cert not trusted — do **Trust the developer certificate** above. App is already installed. |
| "enable Developer Mode" message | Developer Mode toggle now exists in **Settings → Privacy & Security**; turn it on + reboot. |
| Phone not in `flutter devices` | Data cable (not charge-only), unlock phone, tap **Trust**, try a direct USB port. |
| App stopped opening after a week | 7-day cert expired — re-run the install command. |
| Wireless device disappeared | Unlock phone, same Wi-Fi, re-tick **Connect via network** in Xcode Devices window. |
| Signing error in Xcode | Re-pick your **Team** under Signing & Capabilities; make the bundle ID unique. |

---

## Reference

- Device on file: **Autunna** — iPhone 13 Pro Max, iOS 26.5
  - Flutter device id: `00008110-001874C80221801E`
- Backend (prod): `https://gymbro.ddns.net` (see [`config/prod.json`](../config/prod.json))
- Env resolution & config flags: [`lib/core/config/app_config.dart`](../lib/core/config/app_config.dart)
