import SwiftUI

struct DemoCard<Content: View>: View {
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

struct StatusRow: View {
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

struct DemoButton: View {
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

struct SecondaryDemoButton: View {
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
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}

struct StatusPill: View {
    let text: String
    let isActive: Bool

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(isActive ? .blue : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground))
            .cornerRadius(999)
    }
}

struct LogSection: View {
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

func makeDemoLogLine(_ message: String, date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return "[\(formatter.string(from: date))] \(message)"
}

func shortDemoText(_ text: String, limit: Int = 500) -> String {
    guard text.count > limit else { return text }
    return String(text.prefix(limit)) + "..."
}
