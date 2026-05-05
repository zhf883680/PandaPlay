//
//  ServerManagerView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI

struct ServerManagerView: View {
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var toastManager: ToastManager

    @State private var showingAddServer = false
    @State private var serverToDelete: EmbyServer?
    @State private var showingDeleteAlert = false
    @State private var editingServer: EmbyServer?

    var body: some View {
        List {
            ForEach(serverManager.servers) { server in
                HStack {
                    VStack(alignment: .leading) {
                        Text(server.name)
                            .font(.headline)
                        Text(server.url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if server.id == serverManager.currentServer?.id {
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }

                    #if os(tvOS)
                    Spacer()
                    Button {
                        editingServer = server
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)

                    Button {
                        serverToDelete = server
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    #endif
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    switchToServer(server)
                }
                #if os(iOS)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        editingServer = server
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .tint(.blue)

                    Button(role: .destructive) {
                        serverToDelete = server
                        showingDeleteAlert = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                #endif
            }
            .onDelete(perform: deleteServer)

            // Add new server
            Button(action: {
                showingAddServer = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    Text("添加服务器")
                }
            }
        }
        .navigationTitle("服务器管理")
        .sheet(isPresented: $showingAddServer) {
            ServerSetupView()
        }
        .sheet(item: $editingServer) { server in
            ServerSetupView(editingServer: server)
        }
        .alert("删除服务器", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let server = serverToDelete {
                    confirmDelete(server)
                }
            }
        } message: {
            if let server = serverToDelete {
                Text("确定要删除服务器「\(server.name)」吗？此操作不可撤销。")
            }
        }
    }

    private func deleteServer(at offsets: IndexSet) {
        for index in offsets {
            let server = serverManager.servers[index]
            serverToDelete = server
            showingDeleteAlert = true
        }
    }

    private func confirmDelete(_ server: EmbyServer) {
        let deletedCurrentServer = server.id == serverManager.currentServer?.id

        if deletedCurrentServer {
            authManager.logout(serverId: server.id)
        } else {
            authManager.clearSavedCredentials(for: server.id)
        }

        // Remove server
        serverManager.removeServer(server)

        if serverManager.servers.isEmpty {
            serverManager.clearAllServers()
            toastManager.show("已删除服务器", type: .success)
            return
        }

        if deletedCurrentServer, let switchedServer = serverManager.currentServer {
            Task {
                await MainActor.run {
                    authManager.isSwitchingServer = true
                }

                let success = await authManager.tryAutoLogin(
                    serverURL: switchedServer.url,
                    serverId: switchedServer.id
                )

                await MainActor.run {
                    if success {
                        toastManager.show("已切换到 \(switchedServer.name)", type: .success)
                    } else {
                        toastManager.show("已切换到 \(switchedServer.name)，请登录", type: .info)
                    }
                    authManager.isSwitchingServer = false
                }
            }
        } else {
            toastManager.show("已删除服务器", type: .success)
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

            serverManager.setCurrentServer(server)

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
            }
        }
    }
}

#Preview {
    NavigationView {
        ServerManagerView()
            .environmentObject(ServerManager())
    }
}
