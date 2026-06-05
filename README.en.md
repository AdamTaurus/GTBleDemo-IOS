# GD BLE iOS Demo

[中文](README.md)

This is a minimal iOS demo for third-party developers. It shows how to integrate `GD BLE SDK` through a local `GDBleSDK.xcframework`, then scan BLE devices, connect to a discovered device, and request device information.

The demo is built with SwiftUI. The first version only covers the basic BLE flow. Remote keys, file transfer, custom messages, and Wi-Fi images will be added later as separate screens.

## Project Structure

```text
GDBleDemo-iOS/
├── Frameworks/
│   └── GDBleSDK.xcframework      # GD BLE SDK binary
├── GDBleDemo-iOS/
│   ├── GDBleDemo_iOSApp.swift    # SwiftUI app entry
│   ├── ContentView.swift         # Scan, connect, device info, and feature entries
│   ├── BleDemoViewModel.swift    # SDK listener, state, and basic API flow
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

## Implemented Features

- SDK initialization and listener registration: `GDBleClient.shared.addListener(...)`
- BLE scan: `GDBleClient.shared.startScan(timeoutMs:)`
- Stop scan: `GDBleClient.shared.stopScan()`
- Connect to a discovered device: `GDBleClient.shared.connect(device:)`
- Manual disconnect: `GDBleClient.shared.disconnect()`
- Connection state display
- Discovered device list
- Device info request: `GDBleClient.shared.getDeviceInfo()`
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

Remove the listener when the page is destroyed:

```swift
GDBleClient.shared.removeListener(observer)
```

The SDK keeps listeners weakly. The host app must retain the listener instance by itself. This demo stores `BleDemoViewModel` with `@StateObject`, and the ViewModel registers itself as the SDK listener.

