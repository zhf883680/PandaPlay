//
//  LibraryTile.swift
//  PandaPlay
//
//  Created on 2026-05-02.
//

import SwiftUI

struct LibraryTile: View {
    let library: MediaItem

    #if !os(iOS)
    @FocusState private var isFocused: Bool
    #endif

    private var tileWidth: CGFloat {
        DeviceType.current == .iPhone ? 120 : (DeviceType.current == .iPad ? 160 : 200)
    }

    private var tileHeight: CGFloat {
        DeviceType.current == .iPhone ? 100 : (DeviceType.current == .iPad ? 130 : 160)
    }

    private var iconSize: CGFloat {
        DeviceType.current == .iPhone ? 30 : (DeviceType.current == .iPad ? 40 : 50)
    }

    private var iconName: String {
        switch library.collectionType {
        case "movies": return "film"
        case "tvshows": return "tv"
        case "music": return "music.note"
        case "books": return "book"
        case "homevideos": return "video"
        case "photos": return "photo"
        case "playlists": return "list.bullet"
        default: return "folder"
        }
    }

    private var tileColor: Color {
        switch library.collectionType {
        case "movies": return .blue
        case "tvshows": return .purple
        case "music": return .pink
        case "books": return .orange
        case "homevideos": return .green
        case "photos": return .teal
        case "playlists": return .indigo
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tileColor.opacity(0.2))
                    .frame(width: tileWidth, height: tileHeight)

                Image(systemName: iconName)
                    .font(.system(size: iconSize))
                    .foregroundColor(tileColor)
            }
            #if !os(iOS)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            #endif

            Text(library.name ?? "媒体库")
                .font(DeviceType.current == .iPhone ? .caption : .callout)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: tileWidth)
        }
        .contentShape(Rectangle())
        #if !os(iOS)
        .focusable()
        .focused($isFocused)
        #endif
    }
}
