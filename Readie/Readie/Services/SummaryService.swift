// SummaryService.swift
// Summarises voice-memo transcripts on device with Apple's Foundation Models framework
// (Apple Intelligence). Falls back to a simple extractive summary on devices without it.
import Foundation
import FoundationModels
import NaturalLanguage

enum SummaryService {
    static func summarize(_ texts: [String]) async -> String? {
        let joined = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard joined.split(separator: " ").count >= 20 else { return nil }

        if case .available = SystemLanguageModel.default.availability {
            do {
                let session = LanguageModelSession(instructions: """
                    You summarise a reader's spoken notes about books they are reading. \
                    Write 2 to 4 concise sentences, in the same language as the notes, \
                    using only what was said. Do not add opinions or facts.
                    """)
                let response = try await session.respond(to: "Summarise these notes:\n\n\(joined)")
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { return text }
            } catch {
                // fall through to the extractive fallback
            }
        }
        return extractive(joined, sentenceCount: 3)
    }

    /// Picks the sentences that contain the most frequent meaningful words.
    private static func extractive(_ text: String, sentenceCount: Int) -> String {
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        var sentences: [String] = []
        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            sentences.append(String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines))
            return true
        }
        guard sentences.count > sentenceCount else { return text }

        func words(_ s: String) -> [String] {
            let t = NLTokenizer(unit: .word)
            t.string = s
            var out: [String] = []
            t.enumerateTokens(in: s.startIndex..<s.endIndex) { r, _ in
                let w = s[r].lowercased()
                if w.count > 3 { out.append(w) }
                return true
            }
            return out
        }

        var freq: [String: Int] = [:]
        for s in sentences { for w in words(s) { freq[w, default: 0] += 1 } }

        let scored = sentences.enumerated().map { index, s -> (Int, Double) in
            let ws = words(s)
            let score = ws.isEmpty ? 0 : Double(ws.reduce(0) { $0 + freq[$1, default: 0] }) / Double(ws.count)
            return (index, score)
        }
        let top = scored.sorted { $0.1 > $1.1 }.prefix(sentenceCount).map(\.0).sorted()
        return top.map { sentences[$0] }.joined(separator: " ")
    }
}
