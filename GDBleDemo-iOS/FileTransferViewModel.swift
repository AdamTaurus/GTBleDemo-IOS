import Combine
import Foundation
import GDBleSDK

let teleprompterPackageName = "com.goolton.teleprompter"

final class FileTransferViewModel: NSObject, ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var files: [BleFile] = []
    @Published private(set) var latestUploadPath: String?
    @Published private(set) var latestDownloadPath: String?
    @Published private(set) var logs: [String] = []

    private var isListening = false

    deinit {
        GDBleClient.shared.removeListener(self)
    }

    /// File transfer pages only need the high-level SDK callbacks. Fragmenting,
    /// BLE writes, and local file saving are handled inside the SDK.
    func start() {
        guard !isListening else {
            refreshConnectionState()
            return
        }

        GDBleClient.shared.addListener(self)
        isListening = true
        refreshConnectionState()
        appendLog("已打开文件传输页面。")
    }

    func stop() {
        guard isListening else { return }
        GDBleClient.shared.removeListener(self)
        isListening = false
        appendLog("已移除文件传输页面监听。")
    }

    func queryFileList() {
        guard ensureConnected() else { return }
        appendLog("请求文件列表：\(teleprompterPackageName)。")
        GDBleClient.shared.viewFile(pkg: teleprompterPackageName)
    }

    func download(_ file: BleFile) {
        guard ensureConnected() else { return }
        appendLog("请求下载文件：\(file.name)（ID：\(file.id)）。")
        GDBleClient.shared.downloadFile(pkg: teleprompterPackageName, fileId: file.id)
    }

    func uploadTestFile() {
        guard ensureConnected() else { return }

        do {
            let fileURL = try createTestTeleprompterFile()
            latestUploadPath = fileURL.path
            appendLog("已创建测试文件：\(fileURL.path)")
            appendLog("开始上传文件：\(fileURL.lastPathComponent)。")
            GDBleClient.shared.sendFile(fileURL: fileURL, pkg: teleprompterPackageName)
        } catch {
            appendLog("创建测试文件失败：\(error.localizedDescription)")
        }
    }

    func displaySize(for file: BleFile) -> String {
        let size = file.size64 ?? Int64(file.size)
        return "\(size) B"
    }

    func displayTime(for file: BleFile) -> String {
        let seconds = file.time > 10_000_000_000 ? Double(file.time) / 1_000 : Double(file.time)
        let date = Date(timeIntervalSince1970: seconds)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func createTestTeleprompterFile() throws -> URL {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1_000)
        let title = "测试\(timestamp)"
        let content = "这是一段用于 GD BLE SDK 文件上传演示的提词器文本。客户项目可以替换为自己的提词器内容。"
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directoryURL = cachesURL.appendingPathComponent(teleprompterPackageName, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent("\(title).txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func handleFileMessage(_ message: BleMsg) {
        if let pkg = message.pkg, pkg != teleprompterPackageName {
            return
        }

        if message.cmd == .ERROR {
            appendLog("协议返回错误：\(message.action.rawValue)。")
            return
        }

        if message.action == .VIEW_FILE {
            let newFiles = message.data?.fileList ?? []
            files = newFiles
            appendLog("文件列表已更新，共 \(newFiles.count) 个文件。")
            return
        }

        if message.action == .DOWNLOAD_FILE {
            let name = message.data?.file?.name ?? "未知文件"
            appendLog("收到下载响应：\(name)。")
            return
        }

        if message.action == .ADD_FILE {
            appendLog("收到上传响应。")
            return
        }

        if message.cmd == .FILE_END {
            appendLog("文件传输结束。")
        }
    }

    private func ensureConnected() -> Bool {
        if GDBleClient.shared.isConnected() {
            isConnected = true
            return true
        }

        isConnected = false
        appendLog("未连接设备，跳过文件传输操作。")
        return false
    }

    private func refreshConnectionState() {
        isConnected = GDBleClient.shared.isConnected()
    }

    private func appendLog(_ message: String) {
        logs.insert(makeDemoLogLine(message), at: 0)
        if logs.count > 100 {
            logs.removeLast(logs.count - 100)
        }
    }
}

extension FileTransferViewModel: GDBleListener {
    func onConnectionStateChanged(connected: Bool) {
        isConnected = connected
        appendLog(connected ? "设备已连接。" : "设备已断开。")
    }

    func onMessageReceived(message: BleMsg) {
        appendLog("协议消息：action=\(message.action.rawValue)，cmd=\(message.cmd.rawValue)。")
        handleFileMessage(message)
    }

    func onRawMessageReceived(json: String) {
        appendLog("Raw JSON：\(shortDemoText(json))")
    }

    func onFileReceived(absolutePath: String) {
        latestDownloadPath = absolutePath
        appendLog("收到文件：\(absolutePath)")
    }

    func onError(error: GDBleError) {
        refreshConnectionState()
        appendLog("错误：\(error.description)")
    }
}
