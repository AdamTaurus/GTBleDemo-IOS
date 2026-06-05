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
                    FeatureEntrySection()
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
    var body: some View {
        DemoCard(title: "功能入口") {
            VStack(alignment: .leading, spacing: 8) {
                Text("后续会按独立页面补充方向键、文件传输、自定义消息和 Wi-Fi 图片能力。")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    DisabledFeatureRow(title: "方向键控制")
                    DisabledFeatureRow(title: "文件传输")
                    DisabledFeatureRow(title: "自定义消息")
                    DisabledFeatureRow(title: "Wi-Fi 图片")
                }
            }
        }
    }
}

private struct DisabledFeatureRow: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text("后续")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

private struct LogSection: View {
    let logs: [String]

    var body: some View {
        DemoCard(title: "日志") {
            if logs.isEmpty {
                Text("暂无日志。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { _, log in
                        Text(log)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

private struct DemoCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

private struct StatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer(minLength: 0)
        }
    }
}

private struct DemoButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.12))
            .cornerRadius(8)
        }
    }
}
