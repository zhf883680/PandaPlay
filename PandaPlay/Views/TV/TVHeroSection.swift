//
//  TVHeroSection.swift
//  PandaPlay
//
//  tvOS home page hero carousel section.
//

import SwiftUI

#if os(tvOS)
struct TVHeroSection: View {
    let items: [MediaItem]
    let serverURL: String
    var onPlay: ((MediaItem) -> Void)?
    var onDetail: ((MediaItem) -> Void)?

    @State private var currentIndex: Int = 0
    @State private var timer: Timer?
    @FocusState private var isPlayFocused: Bool

    private let height: CGFloat = 550
    private let autoRotateInterval: TimeInterval = 10

    var body: some View {
        if !items.isEmpty {
            ZStack(alignment: .bottomLeading) {
                // Backdrop image
                backdropImage

                // Gradient overlay
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.9)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Content overlay
                VStack(alignment: .leading, spacing: 12) {
                    if let item = currentItems[safe: currentIndex] {
                        heroContent(for: item)
                    }
                }
                .padding(.horizontal, 80)
                .padding(.bottom, 50)
            }
            .frame(height: height)
            .clipped()
            .onAppear {
                startTimer()
                isPlayFocused = true
            }
            .onDisappear {
                stopTimer()
            }
        }
    }

    // MARK: - Views

    @ViewBuilder
    private func heroContent(for item: MediaItem) -> some View {
        // Title
        Text(item.name ?? "")
            .font(.largeTitle)
            .bold()
            .lineLimit(2)

        // Tagline
        if let taglines = item.taglines, let tagline = taglines.first, !tagline.isEmpty {
            Text(tagline)
                .font(.body)
                .italic()
                .foregroundColor(.white.opacity(0.7))
        }

        // Metadata row
        HStack(spacing: 16) {
            if let year = item.productionYear {
                Text("\(year)")
                    .font(.headline)
            }
            if let rating = item.communityRating {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", rating))
                }
                .font(.headline)
            }
            if let genres = item.genres, !genres.isEmpty {
                Text(genres.prefix(3).joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            if let runTimeTicks = item.runTimeTicks {
                let minutes = runTimeTicks / 600_000_000
                Text("\(minutes) 分钟")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }

        // Overview
        if let overview = item.overview, !overview.isEmpty {
            Text(overview)
                .font(.body)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)
        }

        // Buttons
        HStack(spacing: 20) {
            Button {
                onPlay?(item)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("播放")
                }
                .font(.headline)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(8)
            }
            .focused($isPlayFocused)

            Button {
                onDetail?(item)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("详情")
                }
                .font(.headline)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }

        // Page indicators
        if currentItems.count > 1 {
            HStack(spacing: 8) {
                ForEach(currentItems.indices, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var backdropImage: some View {
        if let item = currentItems[safe: currentIndex],
           let imageURL = backdropURL(for: item) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: height)
                case .failure, .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: height)
                        .overlay(
                            Image(systemName: "film")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: height)
        }
    }

    // MARK: - Helpers

    private var currentItems: [MediaItem] {
        Array(items.prefix(5))
    }

    private func backdropURL(for item: MediaItem) -> URL? {
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasSuffix("/") { url += "/" }
        let endpoint = "emby/Items/\(item.id)/Images/Backdrop"
        guard var components = URLComponents(string: url + endpoint) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "maxWidth", value: "1920"),
            URLQueryItem(name: "quality", value: "90")
        ]
        return components.url
    }

    // MARK: - Timer

    private func startTimer() {
        guard currentItems.count > 1 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: autoRotateInterval, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentIndex = (currentIndex + 1) % currentItems.count
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
