//
//  DanmakuOverlayView.swift
//  PandaPlay
//
//  SwiftUI overlay for rendering danmaku (bullet comments) on top of video.
//

import SwiftUI

// MARK: - Render Item

struct DanmakuRenderItem: Identifiable {
    let id: Int
    let comment: DanmakuComment
    let startTimeMs: Double
    var currentX: CGFloat
    let y: CGFloat
    let width: CGFloat
    let durationMs: Double
    let color: Color
    let text: String
    let fontSize: CGFloat
}

// MARK: - Danmaku Overlay

struct DanmakuOverlayView: View {
    let comments: [DanmakuComment]
    let currentTimeMs: Double
    let containerWidth: CGFloat
    let containerHeight: CGFloat

    @State private var visibleItems: [DanmakuRenderItem] = []

    private let baseFontSize: CGFloat = 28
    private let trackHeight: CGFloat = 40
    private let scrollingDurationMs: Double = 8000
    private let fixedDurationMs: Double = 4000
    private let padding: CGFloat = 10

    private var settings: UserDefaultsManager { .shared }

    var body: some View {
        Canvas { context, size in
            for item in visibleItems {
                // Outline
                context.drawLayer { layerContext in
                    // Draw outline shadow for readability
                    for dx: CGFloat in [-1, 0, 1] {
                        for dy: CGFloat in [-1, 0, 1] {
                            if dx != 0 || dy != 0 {
                                layerContext.draw(
                                    Text(item.text)
                                        .font(.system(size: item.fontSize))
                                        .foregroundColor(.black.opacity(0.6)),
                                    at: CGPoint(x: item.currentX + dx, y: item.y + dy),
                                    anchor: .leading
                                )
                            }
                        }
                    }

                    // Draw main text
                    layerContext.draw(
                        Text(item.text)
                            .font(.system(size: item.fontSize))
                            .foregroundColor(item.color),
                        at: CGPoint(x: item.currentX, y: item.y),
                        anchor: .leading
                    )
                }
            }
        }
        .opacity(settings.danmakuOpacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onChange(of: currentTimeMs) { _, newTime in
            updateVisibleItems(at: newTime)
        }
        .onAppear {
            updateVisibleItems(at: currentTimeMs)
        }
    }

    // MARK: - Update Logic

    private func updateVisibleItems(at timeMs: Double) {
        let offsetMs = Double(settings.danmakuOffsetMs)
        let adjustedTime = timeMs + offsetMs

        let density = settings.danmakuDensity
        let areaPercent = settings.danmakuAreaPercent
        let fontScale = settings.danmakuFontScale
        let speedScale = settings.danmakuSpeedScale
        let hideScroll = settings.danmakuHideScroll
        let hideTop = settings.danmakuHideTop
        let hideBottom = settings.danmakuHideBottom

        let maxTracks = max(1, Int((containerHeight * areaPercent) / trackHeight))

        var newItems: [DanmakuRenderItem] = []
        var trackOccupied = Array(repeating: false, count: maxTracks)

        // Sort comments by time
        let sortedComments = comments.filter { comment in
            let mode = comment.mode
            if hideScroll && mode == 1 { return false }
            if hideTop && mode == 5 { return false }
            if hideBottom && mode == 4 { return false }
            return true
        }.sorted { $0.timeMs < $1.timeMs }

        for comment in sortedComments {
            let commentTime = comment.timeMs
            let timeWindow: Double

            switch comment.mode {
            case 4, 5: // fixed (top/bottom)
                timeWindow = fixedDurationMs
            default: // scrolling
                timeWindow = scrollingDurationMs / speedScale
            }

            let endTime = commentTime + timeWindow

            guard adjustedTime >= commentTime && adjustedTime <= endTime else { continue }

            // Density check
            if density > 0 && newItems.count >= density { continue }

            // Find available track
            let (r, g, b) = comment.colorRGB
            let color = Color(red: r, green: g, blue: b)
            let fontSize = baseFontSize * fontScale

            switch comment.mode {
            case 4: // bottom fixed
                let track = maxTracks - 1
                let x = containerWidth / 2
                let y = containerHeight - CGFloat(track + 1) * trackHeight
                let textWidth = estimateTextWidth(comment.m, fontSize: fontSize)

                newItems.append(DanmakuRenderItem(
                    id: comment.cid,
                    comment: comment,
                    startTimeMs: commentTime,
                    currentX: (containerWidth - textWidth) / 2,
                    y: y,
                    width: textWidth,
                    durationMs: timeWindow,
                    color: color,
                    text: comment.m,
                    fontSize: fontSize
                ))

            case 5: // top fixed
                let track = 0
                let y = padding + CGFloat(track) * trackHeight
                let textWidth = estimateTextWidth(comment.m, fontSize: fontSize)

                newItems.append(DanmakuRenderItem(
                    id: comment.cid,
                    comment: comment,
                    startTimeMs: commentTime,
                    currentX: (containerWidth - textWidth) / 2,
                    y: y,
                    width: textWidth,
                    durationMs: timeWindow,
                    color: color,
                    text: comment.m,
                    fontSize: fontSize
                ))

            default: // scrolling
                var assignedTrack = -1
                for t in 0..<maxTracks {
                    if !trackOccupied[t] {
                        assignedTrack = t
                        trackOccupied[t] = true
                        break
                    }
                }
                if assignedTrack < 0 { continue }

                let textWidth = estimateTextWidth(comment.m, fontSize: fontSize)
                let elapsed = adjustedTime - commentTime
                let progress = elapsed / timeWindow
                let x = containerWidth - progress * (containerWidth + textWidth)
                let y = padding + CGFloat(assignedTrack) * trackHeight

                newItems.append(DanmakuRenderItem(
                    id: comment.cid,
                    comment: comment,
                    startTimeMs: commentTime,
                    currentX: x,
                    y: y,
                    width: textWidth,
                    durationMs: timeWindow,
                    color: color,
                    text: comment.m,
                    fontSize: fontSize
                ))
            }
        }

        visibleItems = newItems
    }

    private func estimateTextWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        return CGFloat(text.count) * fontSize * 0.6
    }
}
