//
//  AppError.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import Foundation

enum AppError: Error, LocalizedError {
    // Network errors
    case networkUnavailable
    case serverUnreachable
    case timeout
    case invalidURL

    // Authentication errors
    case authenticationFailed
    case tokenExpired
    case unauthorized
    case userNotFound

    // Server errors
    case serverError(code: Int, message: String)
    case invalidResponse
    case decodingError(Error)

    // Media errors
    case playbackFailed
    case mediaNotFound
    case unsupportedFormat

    // General errors
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        // Network
        case .networkUnavailable:
            return "网络不可用，请检查您的网络连接"
        case .serverUnreachable:
            return "无法连接到服务器，请检查服务器地址"
        case .timeout:
            return "请求超时，请稍后重试"
        case .invalidURL:
            return "无效的服务器地址"

        // Authentication
        case .authenticationFailed:
            return "用户名或密码错误"
        case .tokenExpired:
            return "登录已过期，请重新登录"
        case .unauthorized:
            return "没有权限访问此内容"
        case .userNotFound:
            return "用户不存在"

        // Server
        case .serverError(let code, let message):
            return "服务器错误 (\(code)): \(message)"
        case .invalidResponse:
            return "服务器响应无效"
        case .decodingError:
            return "数据解析失败"

        // Media
        case .playbackFailed:
            return "播放失败，请稍后重试"
        case .mediaNotFound:
            return "找不到媒体文件"
        case .unsupportedFormat:
            return "不支持的视频格式"

        // General
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable, .serverUnreachable:
            return "请检查您的网络连接和服务器状态"
        case .authenticationFailed:
            return "请检查您的用户名和密码"
        case .tokenExpired:
            return "请重新登录"
        case .playbackFailed:
            return "尝试其他视频或检查服务器配置"
        default:
            return nil
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .serverUnreachable, .timeout, .playbackFailed:
            return true
        case .authenticationFailed, .unauthorized, .mediaNotFound, .invalidURL:
            return false
        case .serverError, .invalidResponse, .decodingError, .tokenExpired, .userNotFound, .unsupportedFormat, .unknown:
            return true
        }
    }
}

// MARK: - Error Conversion

extension Error {
    func toAppError() -> AppError {
        if let appError = self as? AppError {
            return appError
        }

        // Handle URLError
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .timeout
            case .cannotConnectToHost, .cannotFindHost:
                return .serverUnreachable
            case .unsupportedURL:
                return .invalidURL
            default:
                return .unknown(urlError)
            }
        }

        return .unknown(self)
    }
}
