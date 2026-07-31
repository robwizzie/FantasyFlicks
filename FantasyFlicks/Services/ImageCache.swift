//
//  ImageCache.swift
//  FantasyFlicks
//
//  In-memory and disk image caching for movie posters
//

import SwiftUI

/// Image cache for efficiently loading and caching movie posters
actor ImageCache {

    // MARK: - Singleton

    static let shared = ImageCache()

    // MARK: - Properties

    /// Lives outside the actor's isolation on purpose. `NSCache` does its own
    /// locking, and keeping it reachable synchronously is what lets
    /// `cachedImage(for:)` answer without an `await` — an actor hop costs at
    /// least one frame, which is long enough for a poster we already hold in
    /// memory to flash its placeholder before appearing.
    private nonisolated(unsafe) static let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        return cache
    }()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    // MARK: - Initialization

    private init() {
        // Set up disk cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("ImageCache", isDirectory: true)

        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public Methods

    /// Memory-cache hit, or nil. Synchronous — never touches disk or network,
    /// so a view can seed itself with an image it already has and render it on
    /// its very first frame.
    nonisolated func cachedImage(for url: URL) -> UIImage? {
        Self.memoryCache.object(forKey: Self.cacheKey(for: url) as NSString)
    }

    /// Get image from cache or download it
    func image(for url: URL) async -> UIImage? {
        let key = Self.cacheKey(for: url)

        // Check memory cache first
        if let cached = Self.memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // Check disk cache
        if let diskImage = loadFromDisk(key: key) {
            Self.memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }

        // Download from network
        do {
            let data = try await NetworkManager.shared.downloadImage(from: url)
            if let image = UIImage(data: data) {
                // Cache in memory
                Self.memoryCache.setObject(image, forKey: key as NSString)
                // Cache to disk
                saveToDisk(image: image, key: key)
                return image
            }
        } catch {
            #if DEBUG
            print("Failed to download image: \(error)")
            #endif
        }

        return nil
    }

    /// Prefetch images for a list of URLs
    func prefetch(urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = await self.image(for: url)
                }
            }
        }
    }

    /// Clear all cached images
    func clearCache() {
        Self.memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Clear memory cache only
    func clearMemoryCache() {
        Self.memoryCache.removeAllObjects()
    }

    // MARK: - Private Methods

    private nonisolated static func cacheKey(for url: URL) -> String {
        url.absoluteString.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
    }

    private func diskURL(for key: String) -> URL {
        cacheDirectory.appendingPathComponent(key)
    }

    private func loadFromDisk(key: String) -> UIImage? {
        let fileURL = diskURL(for: key)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    private func saveToDisk(image: UIImage, key: String) {
        let fileURL = diskURL(for: key)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }
    }
}

// MARK: - Async Image View

/// SwiftUI view for loading cached images asynchronously
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var currentURL: URL?

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder

        // Seed from the memory cache so an image we already hold paints on the
        // first frame. `.task` can only run *after* a frame has been rendered,
        // so without this every rebuilt view shows its placeholder briefly —
        // which reads as a flash when a card is recreated mid-interaction.
        // SwiftUI keeps these initial values only when the state is first
        // created, so a view that's merely re-evaluated keeps what it had.
        let cached = url.flatMap { ImageCache.shared.cachedImage(for: $0) }
        _loadedImage = State(initialValue: cached)
        _currentURL = State(initialValue: cached == nil ? nil : url)
    }

    var body: some View {
        Group {
            if let image = loadedImage, currentURL == url {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = url else {
            loadedImage = nil
            currentURL = nil
            return
        }

        // Already showing this exact image — nothing to do. Skips the actor hop
        // entirely for the common case of a view seeded from the memory cache.
        if currentURL == url, loadedImage != nil { return }

        // If URL changed, reset the loaded image
        if currentURL != url {
            loadedImage = nil
        }

        guard !isLoading else { return }
        isLoading = true
        currentURL = url
        loadedImage = await ImageCache.shared.image(for: url)
        isLoading = false
    }
}

// MARK: - Convenience Extensions

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, content: content) {
            ProgressView()
        }
    }
}

extension CachedAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?) {
        self.init(url: url) { image in
            image
        } placeholder: {
            ProgressView()
        }
    }
}
