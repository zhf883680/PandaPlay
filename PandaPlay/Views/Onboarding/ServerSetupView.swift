//
//  ServerSetupView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI

struct ServerSetupView: View {
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    let editingServer: EmbyServer?

    @State private var serverURL: String = ""
    @State private var serverName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showLoginFields: Bool = false
    @State private var isAttemptingAutoLogin: Bool = false
    @FocusState private var focusedField: Field?

    init(editingServer: EmbyServer? = nil) {
        self.editingServer = editingServer
    }

    enum Field {
        case serverURL, serverName, username, password
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

    private var isEditing: Bool {
        editingServer != nil
    }

    var body: some View {
        VStack(spacing: spacing) {
            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .foregroundColor(.secondary)
                .font(DeviceType.current == .iPhone ? .subheadline : .headline)
            }

            // Logo/Title
            VStack(spacing: DeviceType.current == .iPhone ? 12 : 20) {
                AppLogoView(size: iconSize)

                Text("PandaPlay")
                    .font(DeviceType.current == .iPhone ? .title2 : .title)
                    .bold()

                Text(isEditing ? "编辑服务器信息" : (showLoginFields ? "输入账户信息" : "设置您的 Emby 服务器"))
                    .font(DeviceType.current == .iPhone ? .caption : .subheadline)
                    .foregroundColor(.secondary)
            }

            // Loading state for auto-login
            if isAttemptingAutoLogin {
                VStack(spacing: DeviceType.current == .iPhone ? 10 : 20) {
                    ProgressView()
                        .scaleEffect(DeviceType.current == .iPhone ? 1.2 : 1.5)
                    Text("正在登录...")
                        .foregroundColor(.secondary)
                        .font(DeviceType.current == .iPhone ? .caption : .subheadline)
                }
                .frame(height: DeviceType.current == .iPhone ? 100 : 150)
            }
            // Input Fields
            else {
                VStack(spacing: DeviceType.current == .iPhone ? 12 : 20) {
                    // Server URL (always shown when not auto-logining)
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
                            .disabled(showLoginFields && !isEditing)
                    }

                    // Server Name (always shown when not auto-logining)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("服务器名称（可选）")
                            .font(DeviceType.current == .iPhone ? .subheadline : .headline)
                        TextField("我的服务器", text: $serverName)
                            .padding(DeviceType.current == .iPhone ? 10 : 12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .focused($focusedField, equals: .serverName)
                            .disabled(showLoginFields && !isEditing)
                    }

                    // Login fields (shown after server connection)
                    if showLoginFields && !isEditing {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("用户名")
                                .font(DeviceType.current == .iPhone ? .subheadline : .headline)
                            TextField("输入用户名", text: $username)
                                .padding(DeviceType.current == .iPhone ? 10 : 12)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .autocapitalization(.none)
                                .focused($focusedField, equals: .username)
                                .submitLabel(.next)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("密码")
                                .font(DeviceType.current == .iPhone ? .subheadline : .headline)
                            SecureField("输入密码", text: $password)
                                .padding(DeviceType.current == .iPhone ? 10 : 12)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.done)
                                .onSubmit { loginOrConnect() }
                        }
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

                // Action Button
                Button(action: loginOrConnect) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(DeviceType.current == .iPhone ? 1.2 : 1.5)
                    } else {
                        Text(buttonTitle)
                            .font(DeviceType.current == .iPhone ? .subheadline : .title3)
                            .bold()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isActionDisabled || isLoading)
                .frame(minWidth: DeviceType.current == .iPhone ? 140 : 200)

                Spacer()
            }
        }
        .padding(DeviceType.current == .iPhone ? 20 : horizontalPadding)
        .onAppear {
            if let editingServer {
                serverURL = editingServer.url
                serverName = editingServer.name
                return
            }
        }
    }

    private var buttonTitle: String {
        if isEditing {
            return "保存"
        }
        return showLoginFields ? "登录" : "连接服务器"
    }

    private var isActionDisabled: Bool {
        if isEditing {
            return serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return serverURL.isEmpty || (showLoginFields && (username.isEmpty || password.isEmpty))
    }

    private func loginOrConnect() {
        if isEditing {
            saveEditedServer()
            return
        }

        if showLoginFields {
            login()
        } else {
            connectServer()
        }
    }

    private func attemptAutoLogin(for server: EmbyServer) {
        Task {
            // Try to load saved username
            if let savedUsername = KeychainManager.shared.loadUsername(for: server.id) {
                await MainActor.run {
                    self.username = savedUsername
                }
            }

            // Try auto-login
            let success = await authManager.tryAutoLogin(
                serverURL: server.url,
                serverId: server.id
            )

            await MainActor.run {
                isAttemptingAutoLogin = false
                if success {
                    // Auto-login successful, dismiss the view
                    dismiss()
                } else {
                    // Auto-login failed, show login fields
                    if KeychainManager.shared.loadUsername(for: server.id) != nil {
                        // Had saved credentials but login failed (maybe password changed)
                        errorMessage = "保存的凭据已失效，请重新输入"
                    }
                    withAnimation {
                        showLoginFields = true
                        focusedField = .username
                    }
                }
            }
        }
    }

    private func connectServer() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let client = EmbyClient(serverURL: serverURL)
                _ = try await client.getServerInfo()

                await MainActor.run {
                    // Clear any existing authentication before adding new server
                    if let currentServerId = serverManager.currentServer?.id {
                        authManager.logout(serverId: currentServerId)
                    }

                    serverManager.addServer(url: serverURL, name: serverName)
                    isLoading = false

                    // Show login fields
                    withAnimation {
                        showLoginFields = true
                        focusedField = .username
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "无法连接到服务器，请检查地址"
                    isLoading = false
                }
            }
        }
    }

    private func saveEditedServer() {
        guard let editingServer else {
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let client = EmbyClient(serverURL: serverURL)
                _ = try await client.getServerInfo()

                await MainActor.run {
                    if serverManager.currentServer?.id == editingServer.id {
                        authManager.logout(serverId: editingServer.id)
                    }
                    serverManager.updateServer(
                        id: editingServer.id,
                        url: serverURL,
                        name: serverName
                    )
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "无法连接到服务器，请检查地址"
                    isLoading = false
                }
            }
        }
    }

    private func login() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                guard let serverURL = serverManager.currentServer?.url,
                      let serverId = serverManager.currentServer?.id else {
                    throw EmbyError.invalidURL
                }

                try await authManager.authenticate(
                    serverURL: serverURL,
                    serverId: serverId,
                    username: username,
                    password: password
                )

                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "用户名或密码错误"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ServerSetupView()
        .environmentObject(ServerManager())
        .environmentObject(AuthManager())
}
