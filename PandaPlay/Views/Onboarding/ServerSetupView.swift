//
//  ServerSetupView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI

struct ServerSetupView: View {
    @EnvironmentObject var serverManager: ServerManager
    @Environment(\.dismiss) private var dismiss

    @State private var serverURL: String = ""
    @State private var serverName: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    enum Field {
        case serverURL, serverName
    }

    private var horizontalPadding: CGFloat {
        DeviceType.current == .iPhone ? 24 : (DeviceType.current == .iPad ? 60 : 80)
    }

    private var spacing: CGFloat {
        DeviceType.current == .iPhone ? 20 : 40
    }

    private var iconSize: CGFloat {
        DeviceType.current == .iPhone ? 50 : (DeviceType.current == .iPad ? 70 : 80)
    }

    private var maxWidth: CGFloat {
        DeviceType.current == .iPhone ? .infinity : 500
    }

    var body: some View {
        VStack(spacing: spacing) {
            // Logo/Title
            VStack(spacing: DeviceType.current == .iPhone ? 12 : 20) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.blue)

                Text("PandaPlay")
                    .font(DeviceType.current == .iPhone ? .title2 : .title)
                    .bold()

                Text("设置您的 Emby 服务器")
                    .font(DeviceType.current == .iPhone ? .caption : .subheadline)
                    .foregroundColor(.secondary)
            }

            // Input Fields
            VStack(spacing: DeviceType.current == .iPhone ? 12 : 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("服务器地址")
                        .font(DeviceType.current == .iPhone ? .subheadline : .headline)
                    TextField("https://your-server:8096", text: $serverURL)
                        .padding(DeviceType.current == .iPhone ? 10 : 12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .focused($focusedField, equals: .serverURL)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("服务器名称（可选）")
                        .font(DeviceType.current == .iPhone ? .subheadline : .headline)
                    TextField("我的服务器", text: $serverName)
                        .padding(DeviceType.current == .iPhone ? 10 : 12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .focused($focusedField, equals: .serverName)
                }
            }
            .frame(maxWidth: maxWidth)
            .padding(.horizontal, horizontalPadding)

            // Error Message
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(DeviceType.current == .iPhone ? .caption2 : .caption)
            }

            // Connect Button
            Button(action: connectServer) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(DeviceType.current == .iPhone ? 1.2 : 1.5)
                } else {
                    Text("连接服务器")
                        .font(DeviceType.current == .iPhone ? .subheadline : .title3)
                        .bold()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(serverURL.isEmpty || isLoading)
            .frame(minWidth: DeviceType.current == .iPhone ? 140 : 200)

            Spacer()
        }
        .padding(DeviceType.current == .iPhone ? 20 : horizontalPadding)
    }

    private func connectServer() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let client = EmbyClient(serverURL: serverURL)
                _ = try await client.getServerInfo()

                await MainActor.run {
                    serverManager.addServer(url: serverURL, name: serverName)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "无法连接到服务器，请检查地址"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ServerSetupView()
        .environmentObject(ServerManager())
}
