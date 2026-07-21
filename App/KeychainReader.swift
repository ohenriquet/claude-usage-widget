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
        // CLI primeiro: o item é criado pelo Claude Code via `security`, cuja partition
        // list só autoriza ferramentas Apple — SecItemCopyMatching de um app de terceiros
        // dispara o diálogo de senha a cada leitura, e o "Sempre Permitir" é perdido
        // quando o Claude Code recria o item ao renovar o token OAuth.
        guard let data = readViaSecurityCLI() ?? readViaSecItem(),
              let parsed = try? JSONDecoder().decode(CredentialsFile.self, from: data) else {
            return nil
        }
        return parsed.claudeAiOauth.accessToken
    }

    /// Fallback: dispara o prompt do macOS quando o CLI falhar por algum motivo.
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

    /// Caminho principal, sem prompt: a ACL do item já permite o CLI `security`.
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
