//
//  ErrorManager.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import Foundation
import Combine
import SwiftUI

class ErrorManager: ObservableObject {
    static let shared = ErrorManager()

    @Published var currentError: AppError?
    @Published var showErrorAlert: Bool = false

    private var errorCancellationToken: AnyCancellable?

    private init() {}

    // MARK: - Public Methods

    func handle(_ error: Error) {
        let appError = error.toAppError()

        DispatchQueue.main.async {
            self.currentError = appError
            self.showErrorAlert = true

            // Log the error
            self.logError(appError)
        }
    }

    func handle(_ error: AppError) {
        DispatchQueue.main.async {
            self.currentError = error
            self.showErrorAlert = true

            // Log the error
            self.logError(error)
        }
    }

    func clearError() {
        currentError = nil
        showErrorAlert = false
    }

    // MARK: - Logging

    private func logError(_ error: AppError) {
        #if DEBUG
        print("❌ [Error] \(error.errorDescription ?? "Unknown error")")

        if let suggestion = error.recoverySuggestion {
            print("💡 [Suggestion] \(suggestion)")
        }

        // Log underlying error if available
        switch error {
        case .unknown(let underlyingError):
            print("🔍 [Underlying Error] \(underlyingError)")
        default:
            break
        }
        #endif
    }

    // MARK: - Error Reports

    func reportError(_ error: Error, context: String) {
        #if DEBUG
        print("⚠️ [Error Report] Context: \(context)")
        print("   Error: \(error.localizedDescription)")
        #endif

        // TODO: Send error reports to analytics service
    }
}

// MARK: - View Extension

extension View {
    func errorHandling() -> some View {
        self.environmentObject(ErrorManager.shared)
    }
}

// MARK: - Error Alert Modifier

struct ErrorAlertModifier: ViewModifier {
    @EnvironmentObject var errorManager: ErrorManager

    func body(content: Content) -> some View {
        content
            .alert(isPresented: $errorManager.showErrorAlert) {
                alert(for: errorManager.currentError)
            }
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
                    // Trigger retry action if needed
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

extension View {
    func errorAlert() -> some View {
        self.modifier(ErrorAlertModifier())
    }
}
