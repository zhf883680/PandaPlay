//
//  LoginView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var serverManager: ServerManager
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isAttemptingAutoLogin: Bool = true
    @State private var showEditServerSheet: Bool = false
    @FocusState private var focusedField: Field?

    enum Field {
        case username, password
    }

    private var horizontalPadding: CGFloat {
        DeviceType.current == .iPhone ? 24 : (DeviceType.current == .iPad ? 60 : 80)
    }

    private var spacing: CGFloat {
        DeviceType.current == .iPhone ? 20 : 40
    }

    private var iconSize: CGFloat {
        DeviceType.current == .iPhone ? 60 : (DeviceType.current == .iPad ? 70 : 80)
    }

    private var maxWidth: CGFloat {
        DeviceType.current == .iPhone ? .infinity : 500
    }

    var body: some View {
        VStack(spacing: spacing) {
            HStack {
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .foregroundColor(.secondary)
                .font(DeviceType.current == .iPhone ? .subheadline : .headline)
            }

            // Header
            VStack(spacing: DeviceType.current == .iPhone ? 12 : 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.blue)

                Text("登录到服务器")
                    .font(DeviceType.current == .iPhone ? .title2 : .title)
                    .bold()

                if let serverName = serverManager.currentServer?.name {
                    Text(serverName)
                        .font(DeviceType.current == .iPhone ? .caption : .subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Loading / Auto-login indicator
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("用户名")
                            .font(DeviceType.current == .iPhone ? .subheadline : .headline)
                        TextField("输入用户名", text: $username)
                            .padding(DeviceType.current == .iPhone ? 10 : 12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .autocapitalization(.none)
                            .focused($focusedField, equals: .username)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("密码")
                            .font(DeviceType.current == .iPhone ? .subheadline : .headline)
                        SecureField("输入密码", text: $password)
                            .padding(DeviceType.current == .iPhone ? 10 : 12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .focused($focusedField, equals: .password)
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

                // Login Button
                Button(action: login) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(DeviceType.current == .iPhone ? 1.2 : 1.5)
                    } else {
                        Text("登录")
                            .font(DeviceType.current == .iPhone ? .subheadline : .title3)
                            .bold()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(username.isEmpty || password.isEmpty || isLoading)
                .frame(minWidth: DeviceType.current == .iPhone ? 120 : 200)
            }

            // Change Server Button
            Button("编辑服务器") {
                showEditServerSheet = true
            }
            .foregroundColor(.secondary)
            .font(DeviceType.current == .iPhone ? .caption : .subheadline)
            .disabled(serverManager.currentServer == nil)

            Spacer()
        }
        .padding(DeviceType.current == .iPhone ? 20 : horizontalPadding)
        .onAppear {
            attemptAutoLogin()
        }
        .sheet(isPresented: $showEditServerSheet) {
            if let currentServer = serverManager.currentServer {
                ServerSetupView(editingServer: currentServer)
            }
        }
    }

    private func attemptAutoLogin() {
        Task {
            guard let serverURL = serverManager.currentServer?.url,
                  let serverId = serverManager.currentServer?.id else {
                await MainActor.run {
                    isAttemptingAutoLogin = false
                }
                return
            }

            // Try to load saved username
            if let savedUsername = KeychainManager.shared.loadUsername(for: serverId) {
                await MainActor.run {
                    self.username = savedUsername
                }
            }

            // Try auto-login
            let success = await authManager.tryAutoLogin(serverURL: serverURL, serverId: serverId)

            await MainActor.run {
                isAttemptingAutoLogin = false
                if !success {
                    // If auto-login fails, show the login form
                    if KeychainManager.shared.loadUsername(for: serverId) == nil {
                        // No saved credentials at all
                    }
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
    LoginView()
        .environmentObject(AuthManager())
        .environmentObject(ServerManager())
}
