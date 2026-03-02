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

    var body: some View {
        VStack(spacing: 40) {
            // Logo/Title
            VStack(spacing: 20) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("PandaPlay")
                    .font(.title)
                    .bold()

                Text("设置您的 Emby 服务器")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Input Fields
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("服务器地址")
                        .font(.headline)
                    TextField("https://your-server:8096", text: $serverURL)
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .focused($focusedField, equals: .serverURL)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("服务器名称（可选）")
                        .font(.headline)
                    TextField("我的服务器", text: $serverName)
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .focused($focusedField, equals: .serverName)
                }
            }
            .frame(maxWidth: 500)

            // Error Message
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            // Connect Button
            Button(action: connectServer) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    Text("连接服务器")
                        .font(.title3)
                        .bold()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(serverURL.isEmpty || isLoading)
            .frame(minWidth: 200)

            Spacer()
        }
        .padding(80)
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
