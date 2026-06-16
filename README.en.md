# GD BLE iOS Demo

[中文](README.md)

This is a minimal iOS demo for third-party developers. It shows how to integrate `GD BLE SDK` through a local `GDBleSDK.xcframework`, then scan BLE devices, connect to a discovered device, request device information, send remote key events, transfer app files, and preview/download images through the glasses Wi-Fi service.

The demo is built with SwiftUI. The main screen handles device connection and device info. Other protocol features are split into separate screens so customers can copy only what they need.

## Project Structure

```text
GDBleDemo-iOS/
├── Frameworks/
│   └── GDBleSDK.xcframework      # GD BLE SDK binary
├── GDBleDemo-iOS/
│   ├── GDBleDemo_iOSApp.swift    # SwiftUI app entry
│   ├── ContentView.swift         # Scan, connect, device info, and feature entries
│   ├── BleDemoViewModel.swift    # SDK listener, state, and basic API flow
│   ├── RemoteKeyView.swift       # Remote key control screen
│   ├── RemoteKeyViewModel.swift
│   ├── FileTransferView.swift    # App file transfer screen, using teleprompter as the demo package
│   ├── FileTransferViewModel.swift
│   ├── WifiImageView.swift       # Wi-Fi image preview and download screen
│   ├── WifiImageViewModel.swift
│   ├── RemoteImageView.swift     # iOS 14 compatible remote image loader
│   ├── DemoComponents.swift      # Shared SwiftUI demo components
│   └── Assets.xcassets
├── GDBleDemo-iOS.xcodeproj
├── README.md
└── README.en.md
```

## Requirements

- Xcode: use the current project version or newer
- iOS Deployment Target: 14.0
- A physical iPhone with BLE support
- SDK module: `GDBleSDK`
- SDK facade: `GDBleClient.shared`

## SDK Integration

The demo directly depends on the local `xcframework`:

```text
Frameworks/GDBleSDK.xcframework
```

In Xcode, the framework must be added to:

- Link Binary With Libraries
- Embed Frameworks
- Embed mode: Code Sign On Copy

Import the SDK in Swift:

```swift
import GDBleSDK
```

## Permissions

The host app must add a Bluetooth usage description to its own `Info.plist`. This demo uses a generated Info.plist and configures the key in build settings:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Used to connect to GD BLE devices and exchange data.</string>
```

The SDK does not show business dialogs or wrap permission UI. iOS displays the Bluetooth authorization prompt when CoreBluetooth is used.

The Wi-Fi image screen accesses the glasses-side LAN HTTP service, so the demo also configures:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Used to access the glasses Wi-Fi image service and load thumbnails/full images.</string>

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

## Implemented Features

- SDK initialization and listener registration: `GDBleClient.shared.addListener(...)`
- BLE scan: `GDBleClient.shared.startScan(timeoutMs:)`
- Stop scan: `GDBleClient.shared.stopScan()`
- Connect to a discovered device: `GDBleClient.shared.connect(device:)`
- Manual disconnect: `GDBleClient.shared.disconnect()`
- Connection state display
- Discovered device list
- Device info request: `GDBleClient.shared.getDeviceInfo()`
- Remote key events: `GDBleClient.shared.sendKey(...)`
- App file list query: `GDBleClient.shared.viewFile(pkg:)`
- App file download: `GDBleClient.shared.downloadFile(pkg:fileId:)`
- App file upload: `GDBleClient.shared.sendFile(fileURL:pkg:)`
- Glasses Wi-Fi image service: `GDBleClient.shared.startWifiService()` / `stopWifiService()`
- Image list query: `GDBleClient.shared.viewMedia(type:page:pageSize:)`
- Image thumbnails, full image preview, and full image download into the app sandbox
- Raw protocol JSON logs
- SDK error callback logs

Note: iOS cannot read the BLE MAC address. `GDBleDevice.address` is the peripheral UUID string provided by the system.

## Run

1. Open `GDBleDemo-iOS.xcodeproj` in Xcode.
2. Select the `GDBleDemo-iOS` scheme.
3. Run on a physical iPhone. BLE scan and connection require a real device; the simulator is only useful for build checks.
4. If Xcode reports a signing issue, select your Team in Signing & Capabilities.

You can also run a build check:

```bash
xcodebuild -project GDBleDemo-iOS.xcodeproj -scheme GDBleDemo-iOS -configuration Debug -sdk iphonesimulator build
```

## Basic API Flow

Register an SDK listener:

```swift
final class BleObserver: GDBleListener {
    func onDeviceFound(device: GDBleDevice) {
        print(device.name ?? "-", device.address, device.rssi)
    }

    func onConnectionStateChanged(connected: Bool) {
        print("connected:", connected)
    }

    func onMessageReceived(message: BleMsg) {
        print("message:", message.action.rawValue)
    }

    func onRawMessageReceived(json: String) {
        print("raw:", json)
    }

    func onError(error: GDBleError) {
        print("error:", error)
    }
}

let observer = BleObserver()
GDBleClient.shared.addListener(observer)
```

Start scanning:

```swift
GDBleClient.shared.startScan(timeoutMs: 12_000)
```

Connect to a discovered device:

```swift
GDBleClient.shared.connect(device: device)
```

Request device information after connection:

```swift
GDBleClient.shared.getDeviceInfo()
```

Send remote key events:

```swift
GDBleClient.shared.sendKey(.up)
GDBleClient.shared.sendKey(.center)
GDBleClient.shared.sendKey(.back)
```

App file transfer uses the teleprompter package as an example:

```swift
let pkg = "com.goolton.teleprompter"

GDBleClient.shared.viewFile(pkg: pkg)
GDBleClient.shared.downloadFile(pkg: pkg, fileId: file.id)
GDBleClient.shared.sendFile(fileURL: fileURL, pkg: pkg)
```

To send files to another glasses app, replace `pkg` with the target app's real package name. The glasses side uses `pkg` to manage file list, download, and upload operations.

For a self-developed glasses app, integrating the [GTBle](https://github.com/AdamTaurus/GTBle) `content_sdk` is recommended. It lets the app receive protocol messages and file-change signals through Content Center. Without `content_sdk`, the app can still read the public document directory directly when it starts, resumes, or refreshes manually. The directory is `/Documents/<appFolder>`: built-in apps may use mapped folder names, for example `com.goolton.teleprompter` maps to `Teleprompter`; other package names use the final package segment to generate the folder name by default, for example `com.goolton.launcher` maps to `Launcher`. Direct directory reading only gives the current file snapshot, so the business app will not be notified when files are added or updated.

Wi-Fi image preview and download:

```swift
GDBleClient.shared.startWifiService()

// After receiving Action.WIFI_SERVICE_START, parse NetConfig:
let baseUrl = "http://\(netConfig.ip):\(netConfig.port)"

GDBleClient.shared.viewMedia(type: "image", page: 1, pageSize: 100)

let thumbUrl = "\(baseUrl)/thumb/image/\(file.id)"
let rawUrl = "\(baseUrl)/raw/image/\(file.id)"
```

Remove the listener when the page is destroyed:

```swift
GDBleClient.shared.removeListener(observer)
```

The SDK keeps listeners weakly. The host app must retain the listener instance by itself. This demo stores `BleDemoViewModel` with `@StateObject`, and the ViewModel registers itself as the SDK listener.

## Feature Screens

### Remote Keys

`RemoteKeyView` demonstrates sending key events after the glasses are connected. It includes buttons for `up/down/left/right/center/back/home/refresh`; buttons are disabled when the device is disconnected. In a customer app, call `GDBleClient.shared.sendKey(...)` from the app's own button handler.

### App File Transfer

`FileTransferView` demonstrates package-based app file APIs. The demo uses the teleprompter test package `com.goolton.teleprompter`:

- Tap Query File List to call `viewFile(pkg:)`; read `message.data?.fileList` when `Action.VIEW_FILE` is received.
- Tap Download on a file row to call `downloadFile(pkg:fileId:)`; the completed local path is returned through `onFileReceived(absolutePath:)`.
- Tap Upload Test File to create a random UTF-8 txt file named `测试 + timestamp` in the app cache, then call `sendFile(fileURL:pkg:)`.
- To target another glasses app, use that app's real package name in the SDK calls.
- For self-developed glasses apps, integrating the [GTBle](https://github.com/AdamTaurus/GTBle) `content_sdk` is recommended; without it, the app may read `/Documents/<appFolder>` directly but cannot receive file-change notifications.

### Wi-Fi Images

`WifiImageView` demonstrates the glasses-side Wi-Fi image service:

- Tap Start Wi-Fi Service to call `startWifiService()`; parse `NetConfig` after `Action.WIFI_SERVICE_START` is received.
- The demo polls `/health`, then calls `viewMedia(type: "image", page: 1, pageSize: 100)` when the service is reachable.
- The list loads thumbnails from `/thumb/image/{id}`; tapping an item loads the full image from `/raw/image/{id}`.
- Tap Download Full Image to save the image into the app sandbox at `Documents/GDImages/`. It does not write to Photos, so no Photos permission is required.
- Leaving the page or tapping Stop Wi-Fi Service calls `stopWifiService()` to avoid leaving the glasses service running.
