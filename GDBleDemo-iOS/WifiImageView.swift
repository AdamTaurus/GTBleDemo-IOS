import SwiftUI
import GDBleSDK

struct WifiImageView: View {
    @StateObject private var viewModel = WifiImageViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WifiImageActionPanel(viewModel: viewModel)
                OriginalImageSection(viewModel: viewModel)
                WifiImageListSection(viewModel: viewModel)
                LogSection(logs: viewModel.logs)
            }
            .padding(16)
        }
        .navigationTitle("Wi-Fi 图片")
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

private struct WifiImageActionPanel: View {
    @ObservedObject var viewModel: WifiImageViewModel

    var body: some View {
        DemoCard(title: "Wi-Fi 图片") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusPill(text: viewModel.isConnected ? "已连接" : "未连接", isActive: viewModel.isConnected)
                    StatusPill(text: serviceText, isActive: viewModel.serviceRunning)
                    Spacer()
                }

                StatusRow(title: "本机 IP", value: viewModel.localIp ?? "未获取")
                StatusRow(title: "服务地址", value: viewModel.baseUrl ?? "未开启")

                Text("请和眼镜保持在同一网段。开启服务后，BLE 负责获取列表，图片内容通过眼镜端 HTTP 服务加载。")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    DemoButton(title: "打开 Wi-Fi service", systemImage: "wifi", action: viewModel.startWifiService)
                        .disabled(!viewModel.isConnected || viewModel.checkingService)
                    SecondaryDemoButton(title: "关闭 Wi-Fi service", systemImage: "xmark.circle", action: viewModel.stopWifiService)
                        .disabled(!viewModel.isConnected || (!viewModel.serviceRunning && !viewModel.checkingService))
                }
            }
        }
    }

    private var serviceText: String {
        if viewModel.serviceRunning {
            return "服务已开启"
        }
        if viewModel.checkingService {
            return "服务检测中"
        }
        return "服务未开启"
    }
}

private struct OriginalImageSection: View {
    @ObservedObject var viewModel: WifiImageViewModel

    var body: some View {
        DemoCard(title: "原图预览") {
            if let rawUrl = viewModel.selectedRawUrl, let file = viewModel.selectedImage {
                Text(file.name.isEmpty ? "未命名图片" : file.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                RemoteImageView(urlString: rawUrl, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)

                Text(rawUrl)
                    .font(.caption)
                    .foregroundColor(.secondary)

                DemoButton(title: "下载原图", systemImage: "square.and.arrow.down") {
                    viewModel.downloadOriginal(file)
                }

                if let path = viewModel.latestDownloadPath {
                    StatusRow(title: "最近下载", value: path)
                }
            } else {
                Text("点击图片列表项加载原图。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct WifiImageListSection: View {
    @ObservedObject var viewModel: WifiImageViewModel

    var body: some View {
        DemoCard(title: "图片列表") {
            if viewModel.loadingImages && viewModel.images.isEmpty {
                HStack {
                    ProgressView()
                    Text("正在加载图片列表。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } else if viewModel.images.isEmpty {
                Text("暂无图片，点击“打开 Wi-Fi service”获取图片列表。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 10) {
                    StatusRow(title: "数量", value: "\(viewModel.images.count)")
                    ForEach(viewModel.images, id: \.id) { file in
                        WifiImageRow(file: file, viewModel: viewModel)
                    }
                }
            }
        }
    }
}

private struct WifiImageRow: View {
    let file: BleFile
    @ObservedObject var viewModel: WifiImageViewModel

    private var isSelected: Bool {
        viewModel.selectedImage?.id == file.id
    }

    var body: some View {
        Button {
            viewModel.selectImage(file)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                RemoteImageView(urlString: viewModel.thumbUrl(for: file), contentMode: .fill)
                    .frame(width: 82, height: 82)
                    .background(Color(.tertiarySystemBackground))
                    .clipped()
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(file.name.isEmpty ? "未命名图片" : file.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        Spacer()
                        if isSelected {
                            Text("已选择")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    Text("ID：\(file.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("大小：\(viewModel.displaySize(for: file))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("时间：\(viewModel.displayTime(for: file))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    DemoButton(title: "下载原图", systemImage: "square.and.arrow.down") {
                        viewModel.downloadOriginal(file)
                    }
                }
            }
            .padding(10)
            .background(isSelected ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
