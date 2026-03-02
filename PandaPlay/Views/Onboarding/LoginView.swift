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
    @FocusState private var focusedField: Field?

    enum Field {
        case username, password
    }

    var body: some View {
        VStack(spacing: 40) {
            // Header
            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("登录到服务器")
                    .font(.title)
                    .bold()

                if let serverName = serverManager.currentServer?.name {
                    Text(serverName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Loading / Auto-login indicator
            if isAttemptingAutoLogin {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("正在登录...")
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
            }
            // Input Fields
            else {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("用户名")
                            .font(.headline)
                        TextField("输入用户名", text: $username)
                            .padding(12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .autocapitalization(.none)
                            .focused($focusedField, equals: .username)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("密码")
                            .font(.headline)
                        TextField("输入密码", text: $password)
                            .padding(12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .focused($focusedField, equals: .password)
                    }
                }
                .frame(maxWidth: 500)

                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                // Login Button
                Button(action: login) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else {
                        Text("登录")
                            .font(.title3)
                            .bold()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(username.isEmpty || password.isEmpty || isLoading)
                .frame(minWidth: 200)
            }

            // Change Server Button
            Button("更改服务器") {
                // Clear current server and go back to setup
                authManager.logout()
                serverManager.clearAllServers()
            }
            .foregroundColor(.secondary)

            Spacer()
        }
        .padding(80)
        .onAppear {
            attemptAutoLogin()
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
