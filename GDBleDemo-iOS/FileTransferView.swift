import SwiftUI
import GDBleSDK

struct FileTransferView: View {
    @StateObject private var viewModel = FileTransferViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ActionPanel(viewModel: viewModel)
                TransferResultSection(viewModel: viewModel)
                FileListSection(viewModel: viewModel)
                LogSection(logs: viewModel.logs)
            }
            .padding(16)
        }
        .navigationTitle("文件传输")
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

private struct ActionPanel: View {
    @ObservedObject var viewModel: FileTransferViewModel

    var body: some View {
        DemoCard(title: "提词器文件传输") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusPill(text: viewModel.isConnected ? "已连接" : "未连接", isActive: viewModel.isConnected)
                    Spacer()
                }

                Text("测试包名：\(teleprompterPackageName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("此页面演示查询提词器文件列表、下载文件，以及随机生成 txt 文本文件并上传。")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    DemoButton(title: "查询文件列表", systemImage: "list.bullet", action: viewModel.queryFileList)
                        .disabled(!viewModel.isConnected)
                    DemoButton(title: "上传测试文件", systemImage: "square.and.arrow.up", action: viewModel.uploadTestFile)
                        .disabled(!viewModel.isConnected)
                }
            }
        }
    }
}

private struct TransferResultSection: View {
    @ObservedObject var viewModel: FileTransferViewModel

    var body: some View {
        DemoCard(title: "传输结果") {
            StatusRow(title: "最近上传", value: viewModel.latestUploadPath ?? "无")
            StatusRow(title: "最近下载", value: viewModel.latestDownloadPath ?? "无")
        }
    }
}

private struct FileListSection: View {
    @ObservedObject var viewModel: FileTransferViewModel

    var body: some View {
        DemoCard(title: "文件列表") {
            if viewModel.files.isEmpty {
                Text("暂无文件。点击“查询文件列表”后，提词器文件会显示在这里。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.files, id: \.id) { file in
                        FileRow(file: file, viewModel: viewModel)
                    }
                }
            }
        }
    }
}

private struct FileRow: View {
    let file: BleFile
    @ObservedObject var viewModel: FileTransferViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(file.name)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)

            StatusRow(title: "ID", value: "\(file.id)")
            StatusRow(title: "大小", value: viewModel.displaySize(for: file))
            StatusRow(title: "时间", value: viewModel.displayTime(for: file))

            DemoButton(title: "下载", systemImage: "square.and.arrow.down") {
                viewModel.download(file)
            }
            .disabled(!viewModel.isConnected)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}
