# GD BLE iOS Demo

[English](README.en.md)

这是一个面向第三方客户的最小 iOS Demo，用于演示如何通过本地 `GDBleSDK.xcframework` 接入 GD BLE SDK，并完成 BLE 设备扫描、连接、设备信息读取、方向键控制、提词器文件传输和 Wi-Fi 图片预览下载。

Demo 使用 SwiftUI 实现。首页负责设备连接和设备信息展示，其它协议能力按独立页面拆分，便于客户按需复制。

## 项目结构

```text
GDBleDemo-iOS/
├── Frameworks/
│   └── GDBleSDK.xcframework      # GD BLE SDK 二进制产物
├── GDBleDemo-iOS/
│   ├── GDBleDemo_iOSApp.swift    # SwiftUI App 入口
│   ├── ContentView.swift         # 扫描、连接、设备信息和功能入口
│   ├── BleDemoViewModel.swift    # SDK listener、状态和基础调用流程
│   ├── RemoteKeyView.swift       # 方向键控制页面
│   ├── RemoteKeyViewModel.swift
│   ├── FileTransferView.swift    # 提词器文件传输页面
│   ├── FileTransferViewModel.swift
│   ├── WifiImageView.swift       # Wi-Fi 图片预览和下载页面
│   ├── WifiImageViewModel.swift
│   ├── RemoteImageView.swift     # iOS 14 兼容远程图片加载组件
│   ├── DemoComponents.swift      # Demo 公共 SwiftUI 组件
│   └── Assets.xcassets
├── GDBleDemo-iOS.xcodeproj
├── README.md
└── README.en.md
```

## 环境要求

- Xcode：建议使用当前项目创建时的 Xcode 版本或更新版本
- iOS Deployment Target：14.0
- 真机需要支持 BLE
- SDK module：`GDBleSDK`
- SDK facade：`GDBleClient.shared`

## SDK 接入方式

当前 Demo 直接依赖本地 `xcframework`：

```text
Frameworks/GDBleSDK.xcframework
```

在 Xcode 工程中需要将该 framework 加入：

- Link Binary With Libraries
- Embed Frameworks
- Embed 方式：Code Sign On Copy

Swift 代码中导入 SDK：

```swift
import GDBleSDK
```

## 权限说明

客户 App 必须在自己的 `Info.plist` 中添加蓝牙用途说明。当前 Demo 使用 generated Info.plist，并已在 build settings 中配置：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>用于连接 GD BLE 设备并进行数据通信。</string>
```

SDK 不会主动展示业务弹窗，也不封装权限 UI。iOS 的蓝牙授权弹窗由系统在 CoreBluetooth 使用时触发。

Wi-Fi 图片页面会访问眼镜端局域网 HTTP 服务，因此 Demo 还配置了：

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>用于访问眼镜端 Wi-Fi 图片服务并加载缩略图和原图。</string>

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

## 已实现功能

- SDK 初始化和监听注册：`GDBleClient.shared.addListener(...)`
- BLE 扫描：`GDBleClient.shared.startScan(timeoutMs:)`
- 停止扫描：`GDBleClient.shared.stopScan()`
- 连接扫描到的设备：`GDBleClient.shared.connect(device:)`
- 主动断开：`GDBleClient.shared.disconnect()`
- 连接状态展示
- 扫描设备列表展示
- 设备信息请求：`GDBleClient.shared.getDeviceInfo()`
- 方向键发送：`GDBleClient.shared.sendKey(...)`
- 提词器文件列表查询：`GDBleClient.shared.viewFile(pkg:)`
- 提词器文件下载：`GDBleClient.shared.downloadFile(pkg:fileId:)`
- 提词器 txt 文件上传：`GDBleClient.shared.sendFile(fileURL:pkg:)`
- 眼镜端 Wi-Fi 图片服务：`GDBleClient.shared.startWifiService()` / `stopWifiService()`
- 图片列表查询：`GDBleClient.shared.viewMedia(type:page:pageSize:)`
- 图片缩略图、原图预览和原图下载到 App 沙盒
- 原始协议 JSON 日志展示
- SDK 错误回调日志展示

注意：iOS 无法读取 BLE MAC，`GDBleDevice.address` 使用系统提供的 peripheral UUID 字符串。

## 运行方式

1. 用 Xcode 打开 `GDBleDemo-iOS.xcodeproj`。
2. 选择 `GDBleDemo-iOS` scheme。
3. 选择 iPhone 真机运行。BLE 扫描和连接需要真机，模拟器只能用于编译检查。
4. 如果 Xcode 提示签名问题，在 target 的 Signing & Capabilities 中选择你的 Team。

也可以先执行编译检查：

```bash
xcodebuild -project GDBleDemo-iOS.xcodeproj -scheme GDBleDemo-iOS -configuration Debug -sdk iphonesimulator build
```

## 基础调用流程

注册 SDK listener：

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

开始扫描：

```swift
GDBleClient.shared.startScan(timeoutMs: 12_000)
```

连接扫描到的设备：

```swift
GDBleClient.shared.connect(device: device)
```

连接后读取设备信息：

```swift
GDBleClient.shared.getDeviceInfo()
```

发送方向键：

```swift
GDBleClient.shared.sendKey(.up)
GDBleClient.shared.sendKey(.center)
GDBleClient.shared.sendKey(.back)
```

提词器文件传输使用固定测试包名：

```swift
let pkg = "com.goolton.teleprompter"

GDBleClient.shared.viewFile(pkg: pkg)
GDBleClient.shared.downloadFile(pkg: pkg, fileId: file.id)
GDBleClient.shared.sendFile(fileURL: fileURL, pkg: pkg)
```

Wi-Fi 图片预览和下载：

```swift
GDBleClient.shared.startWifiService()

// 收到 Action.WIFI_SERVICE_START 后解析 NetConfig:
let baseUrl = "http://\(netConfig.ip):\(netConfig.port)"

GDBleClient.shared.viewMedia(type: "image", page: 1, pageSize: 100)

let thumbUrl = "\(baseUrl)/thumb/image/\(file.id)"
let rawUrl = "\(baseUrl)/raw/image/\(file.id)"
```

页面销毁时移除监听：

```swift
GDBleClient.shared.removeListener(observer)
```

Listener 会被 SDK 弱引用保存，宿主 App 需要自己持有 listener 实例。Demo 中使用 `@StateObject` 持有 `BleDemoViewModel`，并由 ViewModel 注册 SDK listener。

## 功能页面

### 方向键控制

`RemoteKeyView` 演示连接后发送按键事件。页面提供 `up/down/left/right/center/back/home/refresh` 全量按钮；未连接时按钮禁用。客户项目只需要在自己的按钮事件中调用 `GDBleClient.shared.sendKey(...)`。

### 提词器文件传输

`FileTransferView` 演示提词器文件能力，测试包名为 `com.goolton.teleprompter`：

- 点击“查询文件列表”调用 `viewFile(pkg:)`，收到 `Action.VIEW_FILE` 后读取 `message.data?.fileList`。
- 文件列表项点击“下载”调用 `downloadFile(pkg:fileId:)`，下载完成路径通过 `onFileReceived(absolutePath:)` 返回。
- 点击“上传测试文件”会在 App cache 下随机创建 `测试 + 时间戳` 的 UTF-8 txt 文件，并调用 `sendFile(fileURL:pkg:)` 上传。

### Wi-Fi 图片

`WifiImageView` 演示眼镜端 Wi-Fi 图片服务：

- 点击“打开 Wi-Fi service”调用 `startWifiService()`，收到 `Action.WIFI_SERVICE_START` 后解析 `NetConfig`。
- Demo 使用 `/health` 做短轮询，服务可访问后调用 `viewMedia(type: "image", page: 1, pageSize: 100)`。
- 图片列表使用 `/thumb/image/{id}` 加载缩略图，点击列表项后使用 `/raw/image/{id}` 加载原图。
- 点击“下载原图”会把原图保存到 App 沙盒 `Documents/GDImages/`，不写入系统相册，因此不需要相册权限。
- 退出页面或点击关闭服务会调用 `stopWifiService()`，避免眼镜端服务残留。
