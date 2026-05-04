//
//  PersonCard.swift
//  PandaPlay
//
//  Created on 2026-05-02.
//

import SwiftUI

struct PersonCard: View {
    let person: MediaPersonInfo
    let serverURL: String

    #if !os(iOS)
    @FocusState private var isFocused: Bool
    #endif

    private var avatarSize: CGFloat {
        DeviceType.current == .iPhone ? 60 : (DeviceType.current == .iPad ? 80 : 100)
    }

    private var cardWidth: CGFloat {
        DeviceType.current == .iPhone ? 80 : (DeviceType.current == .iPad ? 100 : 120)
    }

    private var imageURL: URL? {
        guard !serverURL.isEmpty else { return nil }
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasSuffix("/") {
            url += "/"
        }
        let endpoint = "emby/Items/\(person.id)/Images/Primary"
        var components = URLComponents(string: url + endpoint)
        components?.queryItems = [
            URLQueryItem(name: "maxWidth", value: "200"),
            URLQueryItem(name: "quality", value: "90")
        ]
        return components?.url
    }

    private var initial: String {
        guard let first = person.name.first else { return "?" }
        return String(first)
    }

    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty, .failure:
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: avatarSize, height: avatarSize)
                        Text(initial)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                @unknown default:
                    EmptyView()
                }
            }
            #if !os(iOS)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            #endif

            Text(person.name)
                .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: cardWidth)

            if let role = person.role, !role.isEmpty {
                Text(role)
                    .font(DeviceType.current == .iPhone ? .caption2 : .caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: cardWidth)
            } else if let type = person.type, !type.isEmpty {
                Text(type)
                    .font(DeviceType.current == .iPhone ? .caption2 : .caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: cardWidth)
            }
        }
        .contentShape(Rectangle())
        #if !os(iOS)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .focusable()
        .focused($isFocused)
        #endif
    }
}
