import Foundation

/// Soma tokens/custo de hoje a partir dos transcripts JSONL do Claude Code.
enum TranscriptScanner {
    private struct Entry {
        var model: String
        var inputTokens: Int
        var outputTokens: Int
        var cacheRead: Int
        var cacheWrite5m: Int
        var cacheWrite1h: Int
        var cacheWriteFlat: Int // cache_creation_input_tokens sem breakdown
        var costUSD: Double?    // costUSD da própria linha, quando presente
    }

    static func scanToday(projectsDir: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")) -> TodayStats {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let isoWithFractions = ISO8601DateFormatter()
        isoWithFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()

        // Streaming grava snapshots incrementais da mesma mensagem: dedup por
        // message.id + requestId mantendo a entrada com MAIOR output_tokens.
        var entries: [String: Entry] = [:]
        var anonymousIndex = 0

        let fm = FileManager.default
        let enumerator = fm.enumerator(at: projectsDir, includingPropertiesForKeys: [.contentModificationDateKey],
                                       options: [.skipsHiddenFiles])
        while let file = enumerator?.nextObject() as? URL {
            guard file.pathExtension == "jsonl" else { continue }
            guard let mtime = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                  mtime >= startOfToday else { continue }
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }

            for line in content.split(separator: "\n") {
                // pré-filtro barato antes de parsear JSON
                guard line.contains("\"type\":\"assistant\"") else { continue }
                guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                      obj["type"] as? String == "assistant",
                      let message = obj["message"] as? [String: Any],
                      let usage = message["usage"] as? [String: Any] else { continue }

                guard let ts = obj["timestamp"] as? String,
                      let date = isoWithFractions.date(from: ts) ?? isoPlain.date(from: ts),
                      date >= startOfToday else { continue }

                let model = message["model"] as? String ?? ""
                if model == "<synthetic>" { continue }

                func int(_ key: String) -> Int { (usage[key] as? NSNumber)?.intValue ?? 0 }
                var entry = Entry(
                    model: model,
                    inputTokens: int("input_tokens"),
                    outputTokens: int("output_tokens"),
                    cacheRead: int("cache_read_input_tokens"),
                    cacheWrite5m: 0,
                    cacheWrite1h: 0,
                    cacheWriteFlat: int("cache_creation_input_tokens"),
                    costUSD: (obj["costUSD"] as? NSNumber)?.doubleValue
                )
                if let breakdown = usage["cache_creation"] as? [String: Any] {
                    entry.cacheWrite5m = (breakdown["ephemeral_5m_input_tokens"] as? NSNumber)?.intValue ?? 0
                    entry.cacheWrite1h = (breakdown["ephemeral_1h_input_tokens"] as? NSNumber)?.intValue ?? 0
                    if entry.cacheWrite5m + entry.cacheWrite1h > 0 { entry.cacheWriteFlat = 0 }
                }

                let key: String
                if let id = message["id"] as? String, let requestId = obj["requestId"] as? String {
                    key = "\(id):\(requestId)"
                } else if let id = message["id"] as? String {
                    key = id
                } else {
                    anonymousIndex += 1
                    key = "anon-\(anonymousIndex)"
                }
                if let existing = entries[key], existing.outputTokens >= entry.outputTokens { continue }
                entries[key] = entry
            }
        }

        var stats = TodayStats()
        for entry in entries.values {
            let cacheWrite = entry.cacheWrite5m + entry.cacheWrite1h + entry.cacheWriteFlat
            stats.inputTokens += entry.inputTokens
            stats.outputTokens += entry.outputTokens
            stats.cacheCreationTokens += cacheWrite
            stats.cacheReadTokens += entry.cacheRead

            if let cost = entry.costUSD {
                stats.costUSD += cost
            } else if let price = ModelPrice.forModel(entry.model) {
                let mtok = 1_000_000.0
                stats.costUSD += Double(entry.inputTokens) / mtok * price.input
                    + Double(entry.outputTokens) / mtok * price.output
                    + Double(entry.cacheRead) / mtok * price.cacheRead
                    + Double(entry.cacheWrite5m + entry.cacheWriteFlat) / mtok * price.cacheWrite5m
                    + Double(entry.cacheWrite1h) / mtok * price.cacheWrite1h
            } else {
                stats.costIsPartial = true
            }
        }
        return stats
    }
}
