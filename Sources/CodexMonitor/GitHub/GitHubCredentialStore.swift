import Foundation
import Security

@MainActor
protocol GitHubCredentialStoring: AnyObject {
    func readToken() throws -> String?
    func saveToken(_ token: String) throws
    func deleteToken() throws
}

enum GitHubCredentialError: Error, LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        "无法访问 macOS 钥匙串"
    }
}

@MainActor
final class KeychainGitHubCredentialStore: GitHubCredentialStoring {
    private let service = "com.dafeng.codexmonitor.github"
    private let account = "github-access-token"

    func readToken() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw GitHubCredentialError.keychain(status)
        }
        return token
    }

    func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            attributes as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw GitHubCredentialError.keychain(updateStatus)
        }

        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw GitHubCredentialError.keychain(addStatus)
        }
    }

    func deleteToken() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GitHubCredentialError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
