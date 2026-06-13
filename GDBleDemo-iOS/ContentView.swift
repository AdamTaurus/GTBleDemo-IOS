import SwiftUI
import GDBleSDK

struct ContentView: View {
    @StateObject private var viewModel = BleDemoViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StatusSection(viewModel: viewModel)
                    ActionSection(viewModel: viewModel)
                    DeviceListSection(viewModel: viewModel)
                    DeviceInfoSection(info: viewModel.deviceInfo)
                    FeatureEntrySection(isConnected: viewModel.isConnected)
                    LogSection(logs: viewModel.logs)
                }
                .padding(16)
            }
            .navigationTitle("GD BLE 示例")
            .onAppear {
                viewModel.start()
            }
            .onDisappear {
                viewModel.stop()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct StatusSection: View {
    @ObservedObject var viewModel: BleDemoViewModel

    var body: some View {
        DemoCard(title: "连接状态") {
            StatusRow(title: "蓝牙", value: viewModel.isBluetoothEnabled ? "可用" : "未就绪")
            StatusRow(title: "扫描", value: viewModel.isScanning ? "扫描中" : "未扫描")
            StatusRow(title: "连接", value: connectionText)
            StatusRow(title: "当前设备", value: viewModel.displayName(for: viewModel.selectedDevice))
        }
    }

    private var connectionText: String {
        if viewModel.isConnected { return "已连接" }
        if viewModel.isConnecting { return "连接中" }
        return "未连接"
    }
}

private struct ActionSection: View {
    @ObservedObject var viewModel: BleDemoViewModel

    var body: some View {
        DemoCard(title: "基础操作") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    DemoButton(title: "开始扫描", systemImage: "dot.radiowaves.left.and.right", action: viewModel.startScan)
                    DemoButton(title: "停止扫描", systemImage: "stop.circle", action: viewModel.stopScan)
                }

                HStack(spacing: 10) {
                    DemoButton(title: "断开连接", systemImage: "xmark.circle", action: viewModel.disconnect)
                        .disabled(!viewModel.isConnected && !viewModel.isConnecting)
                    DemoButton(title: "读取设备信息", systemImage: "info.circle", action: viewModel.requestDeviceInfo)
                        .disabled(!viewModel.isConnected)
                }
            }
        }
    }
}

private struct DeviceListSection: View {
    @ObservedObject var viewModel: BleDemoViewModel

    var body: some View {
        DemoCard(title: "扫描设备") {
            if viewModel.devices.isEmpty {
                Text("暂无设备。点击“开始扫描”后，扫描到的设备会显示在这里。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.devices, id: \.address) { device in
                        Button {
                            viewModel.connect(to: device)
                        } label: {
                            DeviceRow(device: device, isSelected: device.address == viewModel.selectedDevice?.address)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

private struct DeviceRow: View {
    let device: GDBleDevice
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("RSSI \(device.rssi)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(device.address)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .background(isSelected ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private var displayName: String {
        let name = device.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name?.isEmpty == false ? name! : "未知设备")
    }
}

private struct DeviceInfoSection: View {
    let info: DeviceInfoSnapshot?

    var body: some View {
        DemoCard(title: "设备信息") {
            if let info {
                if info.rows.isEmpty {
                    Text(info.rawText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(info.rows) { row in
                            StatusRow(title: row.key, value: row.value)
                        }
                    }
                }
            } else {
                Text("连接设备后会自动读取设备信息，也可以点击“读取设备信息”手动刷新。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct FeatureEntrySection: View {
    let isConnected: Bool

    var body: some View {
        DemoCard(title: "功能入口") {
            VStack(alignment: .leading, spacing: 8) {
                Text("连接设备后可进入独立功能页面。iOS Demo 使用 SwiftUI 页面承载功能示例。")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    NavigationLink(destination: RemoteKeyView()) {
                        FeatureRow(
                            title: "方向键控制",
                            subtitle: "发送上、下、左、右、确认、返回、主页、刷新按键",
                            systemImage: "arrow.up.and.down.and.arrow.left.and.right",
                            trailingText: isConnected ? "打开" : "需连接",
                            isEnabled: isConnected
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!isConnected)

                    NavigationLink(destination: FileTransferView()) {
                        FeatureRow(
                            title: "文件传输",
                            subtitle: "查询、下载和上传提词器 txt 文件",
                            systemImage: "doc.text",
                            trailingText: isConnected ? "打开" : "需连接",
                            isEnabled: isConnected
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!isConnected)

                    FeatureRow(
                        title: "自定义消息",
                        subtitle: "后续补充发送 Payload.data 示例",
                        systemImage: "text.bubble",
                        trailingText: "后续",
                        isEnabled: false
                    )

                    NavigationLink(destination: WifiImageView()) {
                        FeatureRow(
                            title: "Wi-Fi 图片",
                            subtitle: "开启眼镜端 Wi-Fi 服务，查看缩略图、原图并下载",
                            systemImage: "photo.on.rectangle",
                            trailingText: isConnected ? "打开" : "需连接",
                            isEnabled: isConnected
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!isConnected)
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let trailingText: String
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(isEnabled ? .blue : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(trailingText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .opacity(isEnabled ? 1 : 0.58)
    }
}
