//
//  KeychainManager.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.pandaplay.emby"

    private init() {}

    // MARK: - Save

    func save(_ data: String, forKey key: String) -> Bool {
        guard let dataFromString = data.data(using: .utf8) else {
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: dataFromString
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        return status == errSecSuccess
    }

    // MARK: - Load

    func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8) {
            return string
        }

        return nil
    }

    // MARK: - Delete

    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Server Credentials

    func savePassword(for serverId: String, password: String) -> Bool {
        return save(password, forKey: "server_\(serverId)_password")
    }

    func loadPassword(for serverId: String) -> String? {
        return load(forKey: "server_\(serverId)_password")
    }

    func saveAccessToken(for serverId: String, token: String) -> Bool {
        return save(token, forKey: "server_\(serverId)_token")
    }

    func loadAccessToken(for serverId: String) -> String? {
        return load(forKey: "server_\(serverId)_token")
    }

    func saveUserId(for serverId: String, userId: String) -> Bool {
        return save(userId, forKey: "server_\(serverId)_userId")
    }

    func loadUserId(for serverId: String) -> String? {
        return load(forKey: "server_\(serverId)_userId")
    }

    func saveUsername(for serverId: String, username: String) -> Bool {
        return save(username, forKey: "server_\(serverId)_username")
    }

    func loadUsername(for serverId: String) -> String? {
        return load(forKey: "server_\(serverId)_username")
    }
}
