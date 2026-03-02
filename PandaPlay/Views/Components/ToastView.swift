//
//  ToastView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI
import Combine

struct ToastView: View {
    let message: String
    let type: ToastType
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            VStack {
                Spacer()

                HStack {
                    Image(systemName: type.icon)
                        .foregroundColor(type.color)

                    Text(message)
                        .font(.body)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        withAnimation {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                .background(type.backgroundColor)
                .cornerRadius(12)
                .shadow(radius: 10)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom))
            }
            .onAppear {
                // Auto dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
        }
    }
}

enum ToastType {
    case success
    case error
    case warning
    case info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    var backgroundColor: Color {
        switch self {
        case .success: return Color.green.opacity(0.9)
        case .error: return Color.red.opacity(0.9)
        case .warning: return Color.orange.opacity(0.9)
        case .info: return Color.blue.opacity(0.9)
        }
    }
}

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    @EnvironmentObject var toastManager: ToastManager

    func body(content: Content) -> some View {
        ZStack {
            content

            ToastView(
                message: toastManager.message,
                type: toastManager.type,
                isPresented: Binding(
                    get: { toastManager.isPresented },
                    set: { toastManager.isPresented = $0 }
                )
            )
        }
    }
}

extension View {
    func automaticToast() -> some View {
        self.modifier(ToastModifier())
    }
}

// MARK: - Toast Manager

class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var isPresented: Bool = false
    @Published var message: String = ""
    @Published var type: ToastType = .info

    private init() {}

    func show(_ message: String, type: ToastType = .info) {
        DispatchQueue.main.async {
            self.message = message
            self.type = type
            self.isPresented = true
        }
    }

    func showSuccess(_ message: String) {
        show(message, type: .success)
    }

    func showError(_ message: String) {
        show(message, type: .error)
    }

    func showWarning(_ message: String) {
        show(message, type: .warning)
    }

    func showInfo(_ message: String) {
        show(message, type: .info)
    }

    func dismiss() {
        isPresented = false
    }
}
