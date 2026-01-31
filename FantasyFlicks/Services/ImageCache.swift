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

    private var memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    // MARK: - Initialization

    private init() {
        // Set up memory cache limits
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB

        // Set up disk cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("ImageCache", isDirectory: true)

        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public Methods

    /// Get image from cache or download it
    func image(for url: URL) async -> UIImage? {
        let key = cacheKey(for: url)

        // Check memory cache first
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // Check disk cache
        if let diskImage = loadFromDisk(key: key) {
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }

        // Download from network
        do {
            let data = try await NetworkManager.shared.downloadImage(from: url)
            if let image = UIImage(data: data) {
                // Cache in memory
                memoryCache.setObject(image, forKey: key as NSString)
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
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Clear memory cache only
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    // MARK: - Private Methods

    private func cacheKey(for url: URL) -> String {
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

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loadedImage {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url = url, !isLoading else { return }
        isLoading = true
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
