//
//  PandaPlayApp.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI

@main
struct PandaPlayApp: App {
    @StateObject private var serverManager = ServerManager()
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(serverManager)
                .environmentObject(authManager)
                .environmentObject(ErrorManager.shared)
                .environmentObject(ToastManager.shared)
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var errorManager: ErrorManager
    @EnvironmentObject var toastManager: ToastManager

    var body: some View {
        ContentView()
            .alert(isPresented: $errorManager.showErrorAlert) {
                alert(for: errorManager.currentError)
            }
            .overlay {
                if toastManager.isPresented {
                    ToastView(
                        message: toastManager.message,
                        type: toastManager.type,
                        isPresented: Binding(
                            get: { toastManager.isPresented },
                            set: { toastManager.isPresented = $0 }
                        )
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeInOut, value: toastManager.isPresented)
    }

    private func alert(for error: AppError?) -> Alert {
        guard let error = error else {
            return Alert(
                title: Text("错误"),
                message: Text("未知错误"),
                dismissButton: .default(Text("确定")) {
                    errorManager.clearError()
                }
            )
        }

        if error.isRetryable {
            return Alert(
                title: Text("发生错误"),
                message: Text(error.errorDescription ?? "未知错误"),
                primaryButton: .cancel(Text("取消")) {
                    errorManager.clearError()
                },
                secondaryButton: .default(Text("重试")) {
                    errorManager.clearError()
                }
            )
        } else {
            return Alert(
                title: Text("发生错误"),
                message: Text(error.errorDescription ?? "未知错误"),
                dismissButton: .default(Text("确定")) {
                    errorManager.clearError()
                }
            )
        }
    }
}
