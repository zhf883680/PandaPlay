//
//  ServerManagerView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI

struct ServerManagerView: View {
    @EnvironmentObject var serverManager: ServerManager

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
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    serverManager.setCurrentServer(server)
                }
            }
            .onDelete(perform: deleteServer)

            // Add new server
            Button("添加服务器") {
                // TODO: Present server setup
            }
        }
        .navigationTitle("服务器管理")
    }

    private func deleteServer(at offsets: IndexSet) {
        for index in offsets {
            let server = serverManager.servers[index]
            serverManager.removeServer(server)
        }
    }
}

#Preview {
    NavigationView {
        ServerManagerView()
            .environmentObject(ServerManager())
    }
}
