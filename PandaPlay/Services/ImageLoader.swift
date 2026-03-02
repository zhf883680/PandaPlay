//
//  ImageLoader.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import Foundation
import SwiftUI
import Combine

class ImageLoader: ObservableObject {
    @Published var image: Image?
    @Published var isLoading: Bool = false

    private var cancellable: AnyCancellable?
    private let cache = ImageCache.shared

    func loadImage(
        serverURL: String,
        itemId: String,
        imageType: ImageType,
        maxWidth: Int = 500,
        maxHeight: Int = 750,
        quality: Int = 90
    ) {
        // Check cache first
        let cacheKey = "\(itemId)_\(imageType)_\(maxWidth)x\(maxHeight)"

        if let cachedImage = cache.image(forKey: cacheKey) {
            self.image = Image(uiImage: cachedImage)
            return
        }

        isLoading = true

        // Build URL
        var baseURL = serverURL
        if !baseURL.hasSuffix("/") {
            baseURL += "/"
        }
        let endpoint = "emby/Items/\(itemId)/Images/\(imageType.rawValue)"
        var urlComponents = URLComponents(string: baseURL + endpoint)!
        urlComponents.queryItems = [
            URLQueryItem(name: "maxWidth", value: String(maxWidth)),
            URLQueryItem(name: "maxHeight", value: String(maxHeight)),
            URLQueryItem(name: "quality", value: String(quality))
        ]

        guard let url = urlComponents.url else {
            isLoading = false
            return
        }

        // Create request
        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        // Download image
        cancellable = URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .replaceError(with: Data())
            .compactMap { UIImage(data: $0) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loadedImage in
                guard let self = self else { return }

                self.isLoading = false
                self.image = Image(uiImage: loadedImage)
                self.cache.setImage(loadedImage, forKey: cacheKey)
            }
    }

    func cancel() {
        cancellable?.cancel()
    }
}

// MARK: - Image Type

enum ImageType: String {
    case primary
    case backdrop
    case banner
    case thumb
    case logo
}

// MARK: - Image Cache

class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 1024 * 1024 * 100 // 100 MB
    }

    func image(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        let cost: Int
        if let cgImage = image.cgImage {
            cost = Int(image.size.width * image.size.height * image.scale * Double(cgImage.bitsPerComponent) / 8)
        } else {
            cost = Int(image.size.width * image.size.height * image.scale * 4) // Assume 4 bytes per pixel
        }
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Async Image View

struct AsyncImageView: View {
    let serverURL: String
    let itemId: String
    let imageType: ImageType
    let maxWidth: Int
    let maxHeight: Int

    @StateObject private var loader = ImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if loader.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        }
        .onAppear {
            loader.loadImage(
                serverURL: serverURL,
                itemId: itemId,
                imageType: imageType,
                maxWidth: maxWidth,
                maxHeight: maxHeight
            )
        }
        .onDisappear {
            loader.cancel()
        }
    }
}
