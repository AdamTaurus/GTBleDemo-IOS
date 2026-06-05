import Combine
import Foundation
import GDBleSDK

final class RemoteKeyViewModel: NSObject, ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var logs: [String] = []

    private var isListening = false

    deinit {
        GDBleClient.shared.removeListener(self)
    }

    /// Each demo page registers its own listener so customers can copy the page
    /// without depending on Main's view model.
    func start() {
        guard !isListening else {
            refreshConnectionState()
            return
        }

        GDBleClient.shared.addListener(self)
        isListening = true
        refreshConnectionState()
        appendLog("已打开方向键页面。")
    }

    func stop() {
        guard isListening else { return }
        GDBleClient.shared.removeListener(self)
        isListening = false
        appendLog("已移除方向键页面监听。")
    }

    func send(_ key: GDBleKey) {
        guard GDBleClient.shared.isConnected() else {
            isConnected = false
            appendLog("未连接设备，跳过发送按键：\(displayName(for: key))。")
            return
        }

        // The SDK serializes the key event into protocol JSON and sends it over BLE.
        appendLog("发送按键：\(displayName(for: key))。")
        GDBleClient.shared.sendKey(key)
    }

    func displayName(for key: GDBleKey) -> String {
        switch key {
        case .up:
            return "上"
        case .down:
            return "下"
        case .left:
            return "左"
        case .right:
            return "右"
        case .center:
            return "确认"
        case .back:
            return "返回"
        case .home:
            return "主页"
        case .refresh:
            return "刷新"
        }
    }

    private func refreshConnectionState() {
        isConnected = GDBleClient.shared.isConnected()
    }

    private func appendLog(_ message: String) {
        logs.insert(makeDemoLogLine(message), at: 0)
        if logs.count > 80 {
            logs.removeLast(logs.count - 80)
        }
    }
}

extension RemoteKeyViewModel: GDBleListener {
    func onConnectionStateChanged(connected: Bool) {
        isConnected = connected
        appendLog(connected ? "设备已连接。" : "设备已断开。")
    }

    func onMessageReceived(message: BleMsg) {
        appendLog("协议消息：action=\(message.action.rawValue)，cmd=\(message.cmd.rawValue)。")
    }

    func onRawMessageReceived(json: String) {
        appendLog("Raw JSON：\(shortDemoText(json))")
    }

    func onError(error: GDBleError) {
        refreshConnectionState()
        appendLog("错误：\(error.description)")
    }
}
