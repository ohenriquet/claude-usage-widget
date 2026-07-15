import Foundation

/// Preços em US$ por milhão de tokens, para estimativa quando a linha não traz costUSD.
/// Sonnet 5 tem preço promocional até 2026-08-31 (2/10); usamos o preço de tabela,
/// o que superestima levemente — aceitável para uma estimativa.
struct ModelPrice {
    let input: Double
    let output: Double
    let cacheWrite5m: Double
    let cacheWrite1h: Double
    let cacheRead: Double

    /// Match por substring no nome do modelo (ex.: "claude-opus-4-8", "claude-fable-5").
    static func forModel(_ model: String) -> ModelPrice? {
        let m = model.lowercased()
        if m.contains("fable") || m.contains("mythos") {
            return ModelPrice(input: 10, output: 50, cacheWrite5m: 12.5, cacheWrite1h: 20, cacheRead: 1.0)
        }
        if m.contains("opus") {
            return ModelPrice(input: 5, output: 25, cacheWrite5m: 6.25, cacheWrite1h: 10, cacheRead: 0.5)
        }
        if m.contains("sonnet") {
            return ModelPrice(input: 3, output: 15, cacheWrite5m: 3.75, cacheWrite1h: 6, cacheRead: 0.3)
        }
        if m.contains("haiku") {
            return ModelPrice(input: 1, output: 5, cacheWrite5m: 1.25, cacheWrite1h: 2, cacheRead: 0.1)
        }
        return nil
    }
}
