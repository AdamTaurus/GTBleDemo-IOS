import SwiftUI
import GDBleSDK

struct RemoteKeyView: View {
    @StateObject private var viewModel = RemoteKeyViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DemoCard(title: "方向键控制") {
                    VStack(alignment: .leading, spacing: 12) {
                        StatusPill(text: viewModel.isConnected ? "已连接" : "未连接", isActive: viewModel.isConnected)
                        Text("向已连接的眼镜发送方向键事件。客户项目通常只需要根据自己的 UI 调用 sendKey。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                DemoCard(title: "按键区") {
                    RemoteKeyPad(isEnabled: viewModel.isConnected) { key in
                        viewModel.send(key)
                    }
                }

                LogSection(logs: viewModel.logs)
            }
            .padding(16)
        }
        .navigationTitle("方向键")
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

private struct RemoteKeyPad: View {
    let isEnabled: Bool
    let onSendKey: (GDBleKey) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Spacer()
                KeyButton(title: "上", key: .up, isEnabled: isEnabled, onSendKey: onSendKey)
                Spacer()
            }

            HStack(spacing: 10) {
                KeyButton(title: "左", key: .left, isEnabled: isEnabled, onSendKey: onSendKey)
                KeyButton(title: "确认", key: .center, isEnabled: isEnabled, onSendKey: onSendKey)
                KeyButton(title: "右", key: .right, isEnabled: isEnabled, onSendKey: onSendKey)
            }

            HStack(spacing: 10) {
                Spacer()
                KeyButton(title: "下", key: .down, isEnabled: isEnabled, onSendKey: onSendKey)
                Spacer()
            }

            HStack(spacing: 10) {
                KeyButton(title: "返回", key: .back, isEnabled: isEnabled, onSendKey: onSendKey)
                KeyButton(title: "主页", key: .home, isEnabled: isEnabled, onSendKey: onSendKey)
                KeyButton(title: "刷新", key: .refresh, isEnabled: isEnabled, onSendKey: onSendKey)
            }
        }
    }
}

private struct KeyButton: View {
    let title: String
    let key: GDBleKey
    let isEnabled: Bool
    let onSendKey: (GDBleKey) -> Void

    var body: some View {
        Button {
            onSendKey(key)
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isEnabled ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground))
                .cornerRadius(8)
        }
        .disabled(!isEnabled)
    }
}
