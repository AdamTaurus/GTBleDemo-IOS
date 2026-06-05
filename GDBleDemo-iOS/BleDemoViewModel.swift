import Combine
import Foundation
import GDBleSDK

struct DeviceInfoRow: Identifiable, Equatable {
    let key: String
    let value: String

    var id: String { key }
}

struct DeviceInfoSnapshot: Equatable {
    let rows: [DeviceInfoRow]
    let rawText: String
}

final class BleDemoViewModel: NSObject, ObservableObject {
    @Published private(set) var devices: [GDBleDevice] = []
    @Published private(set) var isBluetoothEnabled = false
    @Published private(set) var isScanning = false
    @Published private(set) var isConnecting = false
    @Published private(set) var isConnected = false
    @Published private(set) var selectedDevice: GDBleDevice?
    @Published private(set) var deviceInfo: DeviceInfoSnapshot?
    @Published private(set) var logs: [String] = []

    private var isListening = false
    private let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    deinit {
        GDBleClient.shared.removeListener(self)
    }

    /// The SDK keeps listeners weakly. The demo view model is retained by SwiftUI
    /// through @StateObject, so it is a good place to register SDK callbacks.
    func start() {
        guard !isListening else {
            refreshSdkState()
            return
        }

        GDBleClient.shared.addListener(self)
        isListening = true
        refreshSdkState()
        appendLog("SDK 已初始化，已注册监听。")
    }

    func stop() {
        guard isListening else { return }
        GDBleClient.shared.removeListener(self)
        isListening = false
        appendLog("已移除 SDK 监听。")
    }

    func startScan() {
        refreshSdkState()
        devices.removeAll()
        deviceInfo = nil
        selectedDevice = nil
        appendLog("开始扫描 BLE 设备。")

        // iOS 的蓝牙权限弹窗由系统在 CoreBluetooth 使用时触发；SDK 不展示业务弹窗。
        GDBleClient.shared.startScan(timeoutMs: 12_000)
    }

    func stopScan() {
        GDBleClient.shared.stopScan()
        appendLog("已请求停止扫描。")
    }

    func connect(to device: GDBleDevice) {
        selectedDevice = device
        isConnecting = true
        appendLog("开始连接：\(displayName(for: device))。")
        GDBleClient.shared.connect(device: device)
    }

    func disconnect() {
        appendLog("主动断开当前设备。")
        GDBleClient.shared.disconnect()
        isConnecting = false
    }

    func requestDeviceInfo() {
        guard GDBleClient.shared.isConnected() else {
            appendLog("当前未连接设备，无法读取设备信息。")
            return
        }

        appendLog("发送设备信息读取请求。")
        GDBleClient.shared.getDeviceInfo()
    }

    func displayName(for device: GDBleDevice?) -> String {
        guard let device else { return "未选择" }
        let name = device.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name?.isEmpty == false ? name! : "未知设备")
    }

    private func refreshSdkState() {
        isBluetoothEnabled = GDBleClient.shared.isBluetoothEnabled()
        isScanning = GDBleClient.shared.isScanning()
        isConnecting = GDBleClient.shared.isConnecting()
        isConnected = GDBleClient.shared.isConnected()
    }

    private func appendLog(_ message: String) {
        let time = logDateFormatter.string(from: Date())
        logs.insert("[\(time)] \(message)", at: 0)
        if logs.count > 120 {
            logs.removeLast(logs.count - 120)
        }
    }

    private func updateDevice(_ device: GDBleDevice) {
        if let index = devices.firstIndex(where: { $0.address == device.address }) {
            devices[index] = device
        } else {
            devices.append(device)
        }

        devices.sort { left, right in
            if left.rssi == right.rssi {
                return displayName(for: left) < displayName(for: right)
            }
            return left.rssi > right.rssi
        }
    }

    private func handleDeviceInfoMessage(_ message: BleMsg) {
        let rawText = message.data?.data ?? GDBleClient.shared.toJson(message)
        let rows = parseInfoRows(from: rawText)
        deviceInfo = DeviceInfoSnapshot(rows: rows, rawText: rawText)
        appendLog("已收到设备信息。")
    }

    private func parseInfoRows(from text: String) -> [DeviceInfoRow] {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return []
        }

        return dictionary.keys.sorted().map { key in
            DeviceInfoRow(key: key, value: stringify(dictionary[key]))
        }
    }

    private func stringify(_ value: Any?) -> String {
        guard let value else { return "-" }

        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            return text
        }

        return String(describing: value)
    }

    private func shortText(_ text: String, limit: Int = 500) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "..."
    }
}

extension BleDemoViewModel: GDBleListener {
    func onScanStateChanged(scanning: Bool) {
        isScanning = scanning
        isBluetoothEnabled = GDBleClient.shared.isBluetoothEnabled()
        appendLog(scanning ? "扫描已开始。" : "扫描已停止。")
    }

    func onDeviceFound(device: GDBleDevice) {
        updateDevice(device)
        appendLog("发现设备：\(displayName(for: device))，RSSI \(device.rssi)。")
    }

    func onConnectionStateChanged(connected: Bool) {
        isConnected = connected
        isConnecting = false
        isBluetoothEnabled = GDBleClient.shared.isBluetoothEnabled()
        appendLog(connected ? "设备已连接。" : "设备已断开。")

        if connected {
            requestDeviceInfo()
        }
    }

    func onMessageReceived(message: BleMsg) {
        appendLog("协议消息：\(message.action.rawValue)。")

        if message.action == .DEVICE_INFO {
            handleDeviceInfoMessage(message)
        }
    }

    func onRawMessageReceived(json: String) {
        appendLog("Raw JSON：\(shortText(json))")
    }

    func onFileReceived(absolutePath: String) {
        appendLog("收到文件：\(absolutePath)")
    }

    func onError(error: GDBleError) {
        isConnecting = false
        refreshSdkState()
        appendLog("错误：\(error.description)")
    }
}

