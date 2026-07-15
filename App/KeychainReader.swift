import Foundation
import Security

/// Lê o token OAuth que o Claude Code mantém no Keychain de login.
/// NUNCA usa o refreshToken — rotacioná-lo deslogaria o Claude Code.
enum KeychainReader {
    private struct CredentialsFile: Decodable {
        struct OAuth: Decodable {
            let accessToken: String
            let expiresAt: Double? // epoch em milissegundos
        }
        let claudeAiOauth: OAuth
    }

    static func readAccessToken() -> String? {
        guard let data = readViaSecItem() ?? readViaSecurityCLI(),
              let parsed = try? JSONDecoder().decode(CredentialsFile.self, from: data) else {
            return nil
        }
        return parsed.claudeAiOauth.accessToken
    }

    /// Caminho principal: prompt do macOS na primeira vez ("Sempre Permitir" persiste).
    /// Sem kSecUseDataProtectionKeychain — o item vive no keychain file-based de login.
    private static func readViaSecItem() -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "Claude Code-credentials",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            if status != errSecItemNotFound {
                NSLog("ClaudeUsage: SecItemCopyMatching falhou: \(status)")
            }
            return nil
        }
        return data
    }

    /// Fallback sem prompt: a ACL do item já permite o CLI `security`.
    private static func readViaSecurityCLI() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: output, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty else { return nil }
        return text.data(using: .utf8)
    }
}
