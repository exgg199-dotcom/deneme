# NX Injector

Resource mod injector for **Blockman GO** (`com.sandboxol.blockmango`).  
Runs on **stock, non-jailbroken iOS** via TrollStore (CoreTrust signing).  
No root. No jailbreak. The game binary is never modified or re-signed.

---

## How it works

Blockman GO hot-updates its Lua engine and assets into its own writable container:

```
/var/mobile/Containers/Data/Application/<UUID>/Documents/Engine/...
```

NX Injector resolves that container path at runtime via `libsystem_containermanager.dylib`,
activates a sandbox extension token (granted by the private entitlements TrollStore signs),
unzips the user-supplied mod package, and overwrites those files. On next launch the game
loads the modded Lua. The game's App Store binary and signature are never touched.

---

## Requirements

| Requirement | Detail |
|---|---|
| Signing | **TrollStore only** — not AltStore, Sideloadly, or a dev cert |
| iOS | 15.0 – 16.x (tested range; 17+ may need container API updates) |
| Blockman GO | Installed from App Store, **launched at least once** so the container exists |
| Mod file | A `.zip` from your seller — expected name `common_1.zip`, any name accepted |

---

## Install (TrollStore)

1. Download the `NXInjector-unsigned-ipa` artifact from the GitHub Actions run.
2. AirDrop or transfer the IPA to your device.
3. Open **TrollStore** → tap **+** → select the IPA → **Install**.
4. TrollStore signs it with the private entitlements embedded in the IPA.  
   These entitlements (`com.apple.private.security.storage.AppDataContainers`, etc.)  
   are only honored by TrollStore CoreTrust signing — they are ignored by AltStore  
   and standard development certificates.

---

## Usage

1. Open **NX Injector**.
2. Copy your HWID from the Device ID row and send it to your seller.
3. Enter the `NX-XXXXX-XXXXX-XXXXX` key you receive and tap **Activate**.
4. Tap **Pick mod .zip** and select your mod package from Files.
5. Tap **Inject**. Watch the status log for per-file OK / FAIL lines.
6. **Fully close Blockman GO** (swipe away from app switcher) and relaunch.  
   The mod loads on next launch from the replaced engine files.

---

## Entitlements (TrollStore only)

| Entitlement | Purpose |
|---|---|
| `com.apple.private.security.no-container` | Run outside the app's own sandbox |
| `com.apple.private.security.storage.AppDataContainers` | Read/write other apps' Data containers |
| `com.apple.private.security.storage.MobileDocuments` | iCloud Documents access |

These are **real private Apple entitlements** granted by TrollStore's CoreTrust exploit.  
Under AltStore / Sideloadly / standard signing they are silently stripped and injection fails.

---

## Licensing

Set your activation server in `LicenseClient.swift` → `endpoint`:

```swift
private let endpoint = "https://YOUR-AUTH-ENDPOINT/activate"
```

Expected request: `POST {hwid, key}` as JSON.  
Expected response: `{ok: bool, message: string, expires: string?}`.

---

## Building (GitHub Actions)

Every push builds an unsigned IPA via the workflow in `.github/workflows/build-ios.yml`.  
The artifact is named `NXInjector-unsigned-ipa` and retained for 30 days.  
Signing happens on-device via TrollStore — no certificate or provisioning profile needed.

## Project structure

```
project.yml                        XcodeGen manifest (no .xcodeproj committed)
NXInjector/Sources/NXInjector/
  NXInjectorApp.swift              @main entry
  ContentView.swift                SwiftUI UI
  ContainerManager.swift           dlopen wrapper for libsystem_containermanager
  Injector.swift                   Zip unpack + container write logic
  LicenseClient.swift              HWID lock + activation
  HWIDManager.swift                Stable device identifier
NXInjector/Resources/
  Info.plist                       Spoofed bundle ID + capabilities
  NXInjector.entitlements          Private entitlements
```
