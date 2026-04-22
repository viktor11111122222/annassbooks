import SwiftUI
import Combine

private let imageCache = URLCache(
    memoryCapacity: 50 * 1024 * 1024,
    diskCapacity: 300 * 1024 * 1024,
    directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
        .appendingPathComponent("book_covers")
)

private let imageSession: URLSession = {
    let cfg = URLSessionConfiguration.default
    cfg.urlCache = imageCache
    cfg.requestCachePolicy = .returnCacheDataElseLoad
    cfg.timeoutIntervalForRequest = 15
    cfg.httpMaximumConnectionsPerHost = 8
    return URLSession(configuration: cfg)
}()

final class ImageLoader: ObservableObject {
    @Published var uiImage: UIImage?
    private var loadedURL: URL?
    private var task: Task<Void, Never>?

    func load(_ url: URL?) {
        guard let url else { uiImage = nil; return }
        if url == loadedURL, uiImage != nil { return }
        loadedURL = url
        task?.cancel()
        task = Task {
            // Synchronous cache hit
            let cacheReq = URLRequest(url: url, cachePolicy: .returnCacheDataDontLoad, timeoutInterval: 1)
            if let cached = imageCache.cachedResponse(for: cacheReq),
               let img = UIImage(data: cached.data) {
                DispatchQueue.main.async { self.uiImage = img }
                return
            }
            // Network fetch with up to 3 attempts
            let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
            for attempt in 1...3 {
                guard !Task.isCancelled else { return }
                do {
                    let (data, response) = try await imageSession.data(for: req)
                    guard !Task.isCancelled else { return }
                    guard let img = UIImage(data: data) else { break }
                    imageCache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: req)
                    DispatchQueue.main.async { self.uiImage = img }
                    return
                } catch {
                    guard !Task.isCancelled, attempt < 3 else { return }
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 700_000_000)
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    @StateObject private var loader = ImageLoader()

    init(url: URL?,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let img = loader.uiImage {
                content(Image(uiImage: img))
            } else {
                placeholder()
            }
        }
        .onAppear { loader.load(url) }
        .onDisappear { loader.cancel() }
    }
}
