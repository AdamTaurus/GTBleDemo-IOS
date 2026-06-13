import Combine
import Foundation
import GDBleSDK

private let wifiImageMediaType = "image"
private let wifiImagePageSize = 100

struct WifiImagePageInfo: Decodable {
    let page: Int
    let pageSize: Int
    let total: Int
    let totalPages: Int
    let hasNext: Bool
    let mediaType: String?
}

final class WifiImageViewModel: NSObject, ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var localIp: String?
    @Published private(set) var baseUrl: String?
    @Published private(set) var netConfig: NetConfig?
    @Published private(set) var serviceRunning = false
    @Published private(set) var checkingService = false
    @Published private(set) var loadingImages = false
    @Published private(set) var page = 0
    @Published private(set) var total = 0
    @Published private(set) var images: [BleFile] = []
    @Published private(set) var selectedImage: BleFile?
    @Published private(set) var selectedRawUrl: String?
    @Published private(set) var latestDownloadPath: String?
    @Published private(set) var logs: [String] = []

    private var isListening = false
    private var healthCheckWorkItem: DispatchWorkItem?
    private var downloadTask: URLSessionDataTask?

    deinit {
        stopHealthCheck()
        downloadTask?.cancel()
        if serviceRunning || checkingService || baseUrl != nil {
            GDBleClient.shared.stopWifiService()
        }
        GDBleClient.shared.removeListener(self)
    }

    /// This page combines BLE control messages with LAN HTTP image loading.
    /// BLE opens the glasses-side Wi-Fi service and returns its NetConfig;
    /// HTTP then loads thumbnails/full images from that service.
    func start() {
        guard !isListening else {
            refreshConnectionState()
            refreshLocalIp()
            return
        }

        GDBleClient.shared.addListener(self)
        isListening = true
        refreshConnectionState()
        refreshLocalIp()
        appendLog("已打开 Wi-Fi 图片页面。")
    }

    func stop() {
        guard isListening else { return }
        stopWifiService()
        GDBleClient.shared.removeListener(self)
        isListening = false
        appendLog("已移除 Wi-Fi 图片页面监听。")
    }

    func startWifiService() {
        guard GDBleClient.shared.isConnected() else {
            isConnected = false
            appendLog("未连接设备，跳过 Wi-Fi 图片操作。")
            return
        }

        stopHealthCheck()
        refreshLocalIp()
        netConfig = nil
        baseUrl = nil
        serviceRunning = false
        checkingService = true
        loadingImages = false
        page = 0
        total = 0
        images = []
        selectedImage = nil
        selectedRawUrl = nil
        latestDownloadPath = nil

        appendLog("请求打开 Wi-Fi service。")
        GDBleClient.shared.startWifiService()
    }

    func stopWifiService() {
        stopHealthCheck()
        if serviceRunning || checkingService || baseUrl != nil {
            appendLog("请求关闭 Wi-Fi service。")
            GDBleClient.shared.stopWifiService()
        }
        netConfig = nil
        baseUrl = nil
        serviceRunning = false
        checkingService = false
        loadingImages = false
        page = 0
        total = 0
        images = []
        selectedImage = nil
        selectedRawUrl = nil
    }

    func selectImage(_ file: BleFile) {
        guard let baseUrl, !baseUrl.isEmpty else {
            appendLog("缺少眼镜服务地址，无法加载原图。")
            return
        }

        let rawUrl = "\(baseUrl)/raw/image/\(file.id)"
        selectedImage = file
        selectedRawUrl = rawUrl
        appendLog("加载原图：\(rawUrl)")
    }

    func thumbUrl(for file: BleFile) -> String? {
        baseUrl.map { "\($0)/thumb/image/\(file.id)" }
    }

    func rawUrl(for file: BleFile) -> String? {
        baseUrl.map { "\($0)/raw/image/\(file.id)" }
    }

    func downloadOriginal(_ file: BleFile) {
        guard let rawUrl = rawUrl(for: file), let url = URL(string: rawUrl) else {
            appendLog("缺少原图下载地址。")
            return
        }

        appendLog("开始下载原图：\(rawUrl)")
        downloadTask?.cancel()
        downloadTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    self.appendLog("下载原图失败：\(error.localizedDescription)")
                    return
                }

                guard let data, !data.isEmpty else {
                    self.appendLog("下载原图失败：返回数据为空。")
                    return
                }

                do {
                    let savedURL = try self.saveImageData(data, file: file)
                    self.latestDownloadPath = savedURL.path
                    self.appendLog("原图已保存：\(savedURL.path)")
                } catch {
                    self.appendLog("保存原图失败：\(error.localizedDescription)")
                }
            }
        }
        downloadTask?.resume()
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

    private func handleWifiMessage(_ message: BleMsg) {
        if message.cmd == .ERROR {
            checkingService = false
            loadingImages = false
            appendLog("协议返回错误：\(message.action.rawValue)。")
            return
        }

        if message.action == .WIFI_SERVICE_START {
            guard let config = parseNetConfig(message), !config.ip.isEmpty else {
                checkingService = false
                appendLog("Wi-Fi service 未返回有效网络配置。")
                return
            }

            let serviceUrl = "http://\(config.ip):\(config.port)"
            netConfig = config
            baseUrl = serviceUrl
            checkingService = true
            serviceRunning = false
            appendLog("收到眼镜服务地址：\(serviceUrl)")
            waitForWifiService(ip: config.ip, port: config.port)
            return
        }

        if message.action == .WIFI_SERVICE_STOP {
            appendLog("Wi-Fi service 已关闭。")
            return
        }

        if message.action == .VIEW_MEDIA {
            handleViewMedia(message)
        }
    }

    private func handleViewMedia(_ message: BleMsg) {
        let pageInfo = parseMediaPageInfo(message)
        let newImages = (message.data?.fileList ?? []).filter { file in
            let type = file.type ?? ""
            return type.isEmpty || type == wifiImageMediaType
        }
        let merged = (images + newImages)
            .reduce(into: [Int: BleFile]()) { result, file in result[file.id] = file }
            .values
            .sorted { $0.time > $1.time }

        images = merged
        loadingImages = false
        page = pageInfo?.page ?? page
        total = pageInfo?.total ?? merged.count
        appendLog("图片列表已更新，共 \(merged.count) 张。")

        if pageInfo?.hasNext == true {
            requestImagePage(page: (pageInfo?.page ?? page) + 1, reset: false)
        }
    }

    private func waitForWifiService(ip: String, port: Int) {
        stopHealthCheck()
        var workItem: DispatchWorkItem?
        workItem = DispatchWorkItem { [weak self] in
            let available = Self.waitServerAvailable(ip: ip, port: port)
            DispatchQueue.main.async {
                guard let self, let workItem, self.healthCheckWorkItem === workItem, !workItem.isCancelled else { return }
                if available {
                    self.serviceRunning = true
                    self.checkingService = false
                    self.appendLog("Wi-Fi service 可访问，开始请求图片列表。")
                    self.requestImagePage(page: 1, reset: true)
                } else {
                    self.serviceRunning = false
                    self.checkingService = false
                    self.appendLog("Wi-Fi service 不可访问，请确认手机和眼镜在同一网段。")
                }
            }
        }
        healthCheckWorkItem = workItem
        if let workItem {
            DispatchQueue.global(qos: .utility).async(execute: workItem)
        }
    }

    private func requestImagePage(page: Int, reset: Bool) {
        guard GDBleClient.shared.isConnected() else {
            isConnected = false
            loadingImages = false
            appendLog("未连接设备，跳过 Wi-Fi 图片操作。")
            return
        }

        if reset {
            loadingImages = true
            self.page = 0
            total = 0
            images = []
            selectedImage = nil
            selectedRawUrl = nil
        } else {
            loadingImages = true
        }

        appendLog("请求图片列表第 \(page) 页。")
        GDBleClient.shared.viewMedia(type: wifiImageMediaType, page: page, pageSize: wifiImagePageSize)
    }

    private func parseNetConfig(_ message: BleMsg) -> NetConfig? {
        guard let raw = message.data?.data else { return nil }
        return GsonHolder.gson.fromJson(NetConfig.self, raw)
    }

    private func parseMediaPageInfo(_ message: BleMsg) -> WifiImagePageInfo? {
        guard let raw = message.data?.data else { return nil }
        return GsonHolder.gson.fromJson(WifiImagePageInfo.self, raw)
    }

    private func saveImageData(_ data: Data, file: BleFile) throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documents.appendingPathComponent("GDImages", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileName = safeImageFileName(file)
        let destination = directory.appendingPathComponent(fileName)
        try data.write(to: destination, options: [.atomic])
        return destination
    }

    private func safeImageFileName(_ file: BleFile) -> String {
        let trimmedName = file.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedName.isEmpty ? "image-\(file.id).jpg" : trimmedName
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let safe = baseName
            .components(separatedBy: invalid)
            .joined(separator: "-")
        return safe.contains(".") ? safe : "\(safe).jpg"
    }

    private func stopHealthCheck() {
        healthCheckWorkItem?.cancel()
        healthCheckWorkItem = nil
    }

    private func refreshConnectionState() {
        isConnected = GDBleClient.shared.isConnected()
    }

    private func refreshLocalIp() {
        localIp = Self.findLocalIPv4Address()
    }

    private func appendLog(_ message: String) {
        logs.insert(makeDemoLogLine(message), at: 0)
        if logs.count > 120 {
            logs.removeLast(logs.count - 120)
        }
    }
}

extension WifiImageViewModel: GDBleListener {
    func onConnectionStateChanged(connected: Bool) {
        isConnected = connected
        appendLog(connected ? "设备已连接。" : "设备已断开。")
    }

    func onMessageReceived(message: BleMsg) {
        appendLog("协议消息：action=\(message.action.rawValue)，cmd=\(message.cmd.rawValue)。")
        handleWifiMessage(message)
    }

    func onRawMessageReceived(json: String) {
        appendLog("Raw JSON：\(shortDemoText(json))")
    }

    func onError(error: GDBleError) {
        refreshConnectionState()
        checkingService = false
        loadingImages = false
        appendLog("错误：\(error.description)")
    }
}

private extension WifiImageViewModel {
    static func waitServerAvailable(ip: String, port: Int, timeoutMs: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeoutMs)
        var sleepMs: UInt32 = 120_000

        while Date() < deadline {
            if checkHealth(ip: ip, port: port) {
                return true
            }
            usleep(sleepMs)
            sleepMs = min(UInt32(Double(sleepMs) * 1.5), 350_000)
        }
        return false
    }

    static func checkHealth(ip: String, port: Int) -> Bool {
        guard let url = URL(string: "http://\(ip):\(port)/health") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.35

        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse {
                success = http.statusCode == 200
            }
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + 0.5)
        return success
    }

    static func findLocalIPv4Address() -> String? {
        var address: String?
        var interfaces: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else {
            return nil
        }
        defer { freeifaddrs(interfaces) }

        for pointer in sequence(first: firstInterface, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isRunning = (flags & IFF_RUNNING) == IFF_RUNNING
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            guard isUp && isRunning && !isLoopback else { continue }
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: interface.ifa_name)
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            let candidate = String(cString: hostname)
            if name == "en0" {
                return candidate
            }
            if address == nil {
                address = candidate
            }
        }

        return address
    }
}
