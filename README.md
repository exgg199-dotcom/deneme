# NX Injector

iOS resource injector for Blockman GO (com.sandboxol.blockmango).  
Targets TrollStore / ldid-signed environments on jailbroken devices.

## Building

GitHub Actions builds an unsigned IPA on every push.  
Download the `NXInjector-unsigned-ipa` artifact from the Actions tab.

## Signing (phone-side)

### TrollStore
1. Download the IPA to your device (Safari, Files, AirDrop).
2. Open TrollStore → tap **+** → select the IPA.
3. TrollStore signs it with the private entitlements embedded in the IPA.

### ldid (SSH / terminal)
```bash
ldid -SNXInjector/Resources/NXInjector.entitlements NXInjector.app/NXInjector
```

### KSign / ESign
Import the unsigned IPA, sign with any certificate, install.  
Private entitlements (`com.apple.private.*`) only activate under TrollStore or ldid.

## Entitlements note

The entitlements plist requests private Apple entitlements:

| Key | Purpose |
|-----|---------|
| `com.apple.private.security.no-container` | Run outside sandbox |
| `com.apple.private.security.storage.AppDataContainers` | Read/write other app containers |
| `com.apple.private.security.storage.MobileDocuments` | iCloud Documents access |

These are **ignored** by the App Store and by standard ad-hoc signing.  
They only take effect when signed with TrollStore or ldid on a jailbroken device.

## Licensing

The app requires a valid `NX-XXXXX-XXXXX-XXXXX` license key.  
Set your activation endpoint in `LicenseClient.swift` → `endpoint`.

## Container access

Uses `libsystem_containermanager.dylib` via `dlopen` to resolve  
`/var/mobile/Containers/Data/Application/<UUID>` for Blockman GO and  
activates a sandbox extension token so writes are permitted.

Tested path on iOS 15–16. iOS 17+ may require a different approach  
if `container_object_copy_sandbox_token` is unavailable; the app  
shows a clear error in that case.
