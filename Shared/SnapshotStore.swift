import Foundation

/// Lê/grava o snapshot no container do App Group. Compartilhado entre app e widget.
enum SnapshotStore {
    static var appGroupID: String {
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String) ?? ""
    }

    static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("snapshot.json")
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func load() -> UsageSnapshot? {
        guard let url = snapshotURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(UsageSnapshot.self, from: data)
    }

    /// Grava atômico para o widget nunca ler JSON truncado.
    @discardableResult
    static func save(_ snapshot: UsageSnapshot) -> Bool {
        guard let url = snapshotURL,
              let data = try? encoder.encode(snapshot) else { return false }
        do {
            // Em apps não-sandboxed o containerURL NÃO cria o diretório sozinho.
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            NSLog("ClaudeUsage: falha ao gravar snapshot: \(error)")
            return false
        }
    }
}
