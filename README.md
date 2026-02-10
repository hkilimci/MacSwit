## MacSwit

Menu-bar utility that watches your Mac's battery level and toggles a smart plug on or off to keep the charge within a configurable window. The provider architecture is extensible — Tuya is the only supported provider today, but adding new brands (Meross, Kasa, etc.) requires implementing a single protocol.

### How it works

1. **`MacSwitApp`** launches, wires an `AppDelegate` for shutdown handling, and creates a shared `AppState`. A `MenuBarExtra` shows a plug icon (filled when the plug is on).
2. **`AppState`** loads persisted thresholds, polling interval, and preferences via `@AppStorage`. It asks `PlugStore` for the active plug configuration and builds a provider controller through `PlugProviderFactory`.
3. A repeating **`Timer`** (minimum 60 s) calls `performCheck`, which runs `BatteryReader` off the main thread to read the current percentage via IOKit (falling back to `pmset -g batt`).
4. **`evaluateBattery`** compares the reading to the on/off thresholds, validates `on < off`, and deduplicates commands — the same action is never sent twice until the opposite action occurs.
5. When an action is needed, the active `PlugProviding` controller sends the command. For Tuya, `TuyaPlugController` delegates to `TuyaClient` — an actor that lazily fetches a token via `/v1.0/token`, caches it until one minute before expiry, verifies the device is online, and signs REST calls with HMAC-SHA256 before hitting `/v1.0/iot-03/devices/{deviceId}/commands`.
6. **`PlugStore`** manages multiple plug configurations persisted in `UserDefaults`, with credentials (Access ID and Access Secret) stored per-plug in the login keychain.
7. On quit, `AppDelegate` optionally sends a switch-off command (with a 3-second timeout) if the user has enabled **Switch off on shutdown**.

### Project structure

```
MacSwit/
├── MacSwitApp.swift              # App entry point, MenuBarExtra + Settings scene
├── AppDelegate.swift             # Shutdown handler (switch-off on quit)
├── State/
│   ├── AppState.swift            # Central state: timer, battery check, plug control
│   └── AppSettings.swift         # AppStorage keys and default constants
├── Models/
│   ├── PlugConfig.swift          # Per-plug configuration (name, provider, fields)
│   └── TuyaEndpoint.swift        # Tuya region endpoints
├── Services/
│   ├── BatteryReader.swift       # IOKit / pmset battery reading
│   ├── KeychainStore.swift       # Login keychain wrapper
│   ├── PlugStore.swift           # Multi-plug CRUD + active selection
│   └── TuyaClient.swift          # Tuya REST API actor (token, signing, commands)
├── Providers/
│   ├── SmartPlugProvider.swift   # PlugProviding protocol, ProviderType, PlugProviderFactory
│   └── Tuya/
│       ├── TuyaPlugController.swift   # PlugProviding implementation for Tuya
│       └── TuyaPlugFieldsView.swift   # Tuya-specific settings form fields
├── Views/
│   ├── MenuView.swift            # Menu-bar popup (battery, status, enable/disable, quit)
│   ├── SettingsView.swift        # Settings window (Battery, Smart Plug, General tabs)
│   └── PlugEditView.swift        # Add/edit plug sheet (credentials, provider fields, test)
├── Helpers/
│   └── CryptoHelpers.swift       # SHA-256 and HMAC-SHA256 utilities
└── landing/
    └── index.html                # Product landing page (dark/light mode, EN/TR)
```

### Requirements

- macOS 13.0+ (Menu Bar Extra + login-item APIs). Login-item support requires a signed `.app` bundle.
- Xcode 15+ / Swift 5.9 toolchain.
- A Tuya developer account with a cloud project and a device already paired to that project.
- Tuya API credentials: Access ID, Access Secret, region endpoint (EU/US/CN or custom), Device ID, and optional DP code (defaults to `switch_1`).

### Building & running

1. Open `MacSwit.xcodeproj` in Xcode and select the **MacSwit** scheme.
2. Set a signing team so the app can request login-item privileges.
3. Build & run. The app appears in the menu bar as a plug icon.

### Configuration

1. Open **Settings** from the menu-bar popup.

2. **Battery** tab — set the lower/upper thresholds (plug turns ON at/below lower, OFF at/above upper). The sliders enforce a 5 % gap.

3. **Smart Plug** tab — manage your plugs. Click **Add Plug** to configure a new device, or edit/delete existing ones. One plug is active at a time; the active plug is used for automatic control.

4. In the plug editor, select the provider (currently Tuya), pick a region endpoint or enter a custom host, fill in Access ID, Access Secret, Device ID, and an optional DP code. Credentials are stored in the login keychain.

5. Use **Test ON / Test OFF** to verify the relay reacts, and **Verify Token** to confirm authentication works before relying on automation.

6. **General** tab — toggle **Enable MacSwit**, **Launch at login**, and the experimental **Switch off on shutdown** option.

### Tuya API credentials guide

Follow these steps to collect the values the plug editor requires:

1. **Create a cloud project.** Sign in to the Tuya IoT Platform, go to **Cloud → Development**, and create a project in the same data center (EU/US/CN/other) as your hardware. Under **Authorization Management**, enable at least *Device Status*, *Device Control*, and *Token Service* APIs.
2. **Link the mobile app.** In the project's **Link Tuya App** section, scan the QR code with the Smart Life or Tuya Smart app that controls the plug.
3. **Access ID & Access Secret.** In the project dashboard under **Authorization Key** (or *Project Configuration*), copy the Access ID and Access Secret.
4. **Device ID.** Pair the plug in Smart Life/Tuya Smart first. Then in the IoT Platform go to **Devices → All Devices** and copy the device's 20+ character ID.
5. **DP code.** Open the device detail page, choose **Standard Instruction Set** (Functions). Most single-gang plugs use `switch_1`; multi-gang plugs expose `switch_2`, etc.
6. **Endpoint / region host.** Match the host to your project's data center:
   | Data center | Host |
   |---|---|
   | China (Shanghai, Alibaba) | `openapi.tuyacn.com` |
   | Western America (Oregon, AWS) | `openapi.tuyaus.com` |
   | Eastern America (Virginia, Azure) | `openapi-ueaz.tuyaus.com` |
   | Central Europe (Frankfurt, AWS) | `openapi.tuyaeu.com` |
   | Western Europe (Amsterdam, Azure) | `openapi-weaz.tuyaeu.com` |
   | India (Mumbai, AWS) | `openapi.tuyain.com` |
   | Singapore (Alibaba) | `openapi-sg.iotbing.com` |
   | Other / private | Choose **Custom** and enter the hostname |
7. **Verify via API Explorer (optional).** Before switching to MacSwit, use the IoT Platform's API Explorer to test `GET /v1.0/token`, `GET /v1.0/iot-03/devices/{device_id}`, and `POST /v1.0/iot-03/devices/{device_id}/commands` with `{ "code": "switch_1", "value": true }`.
8. Enter the values in MacSwit's plug editor, save, and run the built-in test buttons.

### Adding a new provider

The codebase is designed for extensibility. To add a new smart plug brand:

1. Add a case to `ProviderType` in `SmartPlugProvider.swift` (e.g. `case meross = "meross"`).
2. Create `Providers/<Brand>/<Brand>PlugController.swift` conforming to the `PlugProviding` protocol.
3. Create `Providers/<Brand>/<Brand>PlugFieldsView.swift` with the brand-specific settings form.
4. Add the case to `PlugProviderFactory.make(config:accessId:accessSecret:)`.
5. Add the case to `PlugEditView.providerFieldsView`.
6. Add provider-specific fields to `PlugConfig`.

### Behavior notes

- Battery readings use IOKit when available and fall back to `pmset -g batt`.
- Command deduplication ensures the same action (ON or OFF) is never sent twice — only a threshold crossing in the opposite direction triggers a new command.
- Tuya tokens are cached until ~1 minute before expiry; saving new credentials clears the cache automatically.
- Each plug's Access ID and Access Secret are stored in the login keychain under `MacSwit.plug.<uuid>.accessId` and `MacSwit.plug.<uuid>.accessSecret`.

