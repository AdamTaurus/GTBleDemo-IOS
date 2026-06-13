import Combine
import SwiftUI

final class RemoteImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var errorText: String?

    private var task: URLSessionDataTask?

    deinit {
        task?.cancel()
    }

    func load(_ urlString: String?) {
        task?.cancel()
        image = nil
        errorText = nil

        guard let urlString, let url = URL(string: urlString) else {
            isLoading = false
            return
        }

        isLoading = true
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorText = error.localizedDescription
                    return
                }

                guard let data, let image = UIImage(data: data) else {
                    self.errorText = "图片数据无效"
                    return
                }

                self.image = image
            }
        }
        task?.resume()
    }
}

struct RemoteImageView: View {
    let urlString: String?
    let contentMode: ContentMode

    @StateObject private var loader = RemoteImageLoader()

    var body: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if loader.isLoading {
                ProgressView()
            } else if let errorText = loader.errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(6)
            } else {
                Text("等待图片")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loader.load(urlString)
        }
        .onChange(of: urlString) { newValue in
            loader.load(newValue)
        }
    }
}
