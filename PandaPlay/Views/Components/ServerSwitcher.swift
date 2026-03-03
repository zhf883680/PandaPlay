//
//  ServerSwitcher.swift
//  PandaPlay
//
//  Created on 2026-03-03.
//

import SwiftUI

struct ServerSwitcher: View {
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var toastManager: ToastManager

    @State private var showingServerList = false
    @State private var showingAddServer = false

    var body: some View {
        if let currentServer = serverManager.currentServer {
            #if os(tvOS)
            tvOSServerButton(server: currentServer)
            #else
            iOSServerMenu(server: currentServer)
            #endif
        } else {
            // No server selected - show add button
            Button(action: {
                showingAddServer = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                    Text("添加服务器")
                        .font(.headline)
                }
            }
            .sheet(isPresented: $showingAddServer) {
                ServerSetupView()
            }
        }
    }

    // MARK: - iOS Implementation

    @ViewBuilder
    private func iOSServerMenu(server: EmbyServer) -> some View {
        Menu {
            // Server list
            ForEach(serverManager.servers) { serverItem in
                Button(action: {
                    switchToServer(serverItem)
                }) {
                    HStack {
                        Text(serverItem.name)
                        if serverItem.id == server.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            // Add server button
            Button(action: {
                showingAddServer = true
            }) {
                Label("添加服务器", systemImage: "plus.circle")
            }

            Divider()

            // Server management
            Button(action: {
                showingServerList = true
            }) {
                Label("服务器管理", systemImage: "gearshape")
            }
        } label: {
            HStack(spacing: 4) {
                Text(server.name)
                    .font(.headline)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
        .sheet(isPresented: $showingServerList) {
            ServerManagementSheet()
        }
        .sheet(isPresented: $showingAddServer) {
            ServerSetupView()
        }
    }

    // MARK: - tvOS Implementation

    @ViewBuilder
    private func tvOSServerButton(server: EmbyServer) -> some View {
        Button(action: {
            showingServerList = true
        }) {
            HStack(spacing: 8) {
                Text(server.name)
                    .font(.headline)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
        .sheet(isPresented: $showingServerList) {
            ServerListView()
        }
    }
}

// MARK: - Server List View (tvOS)

struct ServerListView: View {
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var toastManager: ToastManager
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedServerId: String?
    @State private var showingAddServer = false

    var body: some View {
        NavigationView {
            List {
                // Add new server button
                Button(action: {
                    showingAddServer = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("添加服务器")
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)

                Divider()

                // Existing servers
                ForEach(serverManager.servers) { server in
                    Button(action: {
                        switchToServer(server)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(server.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(server.url)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if server.id == serverManager.currentServer?.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .focused($focusedServerId, equals: server.id)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("选择服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddServer) {
                ServerSetupView()
            }
        }
    }

    private func switchToServer(_ server: EmbyServer) {
        guard server.id != serverManager.currentServer?.id else {
            return
        }

        Task {
            await MainActor.run {
                authManager.isSwitchingServer = true
                authManager.clearSession()
            }

            // Switch to new server
            serverManager.switchServer(server)

            // Try to auto-login with saved credentials for new server
            let success = await authManager.tryAutoLogin(
                serverURL: server.url,
                serverId: server.id
            )

            await MainActor.run {
                if success {
                    toastManager.show("已切换到 \(server.name)", type: .success)
                } else {
                    toastManager.show("已切换到 \(server.name)，请登录", type: .info)
                }
                authManager.isSwitchingServer = false
                dismiss()
            }
        }
    }
}

// MARK: - Server Management Sheet (iOS)

struct ServerManagementSheet: View {
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var toastManager: ToastManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddServer = false

    var body: some View {
        NavigationView {
            ServerManagerView()
                .navigationTitle("服务器管理")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            showingAddServer = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddServer) {
                    ServerSetupView()
                }
        }
    }
}

// MARK: - Helper Methods

private extension ServerSwitcher {
    func switchToServer(_ server: EmbyServer) {
        guard server.id != serverManager.currentServer?.id else {
            return
        }

        Task {
            await MainActor.run {
                authManager.isSwitchingServer = true
                authManager.clearSession()
            }

            // Switch to new server
            serverManager.switchServer(server)

            // Try to auto-login with saved credentials for new server
            let success = await authManager.tryAutoLogin(
                serverURL: server.url,
                serverId: server.id
            )

            await MainActor.run {
                if success {
                    toastManager.show("已切换到 \(server.name)", type: .success)
                }
                // If no saved credentials, login screen will show automatically
                authManager.isSwitchingServer = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        ServerSwitcher()
            .environmentObject(ServerManager())
            .environmentObject(AuthManager())
            .environmentObject(ToastManager.shared)
    }
}
