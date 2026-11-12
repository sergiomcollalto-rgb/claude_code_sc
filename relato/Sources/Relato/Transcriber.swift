import AVFoundation
import CoreMedia
import Speech

struct Segment {
    var start: Double
    var speaker: String
    var text: String
}

enum TranscriberError: LocalizedError {
    case localeUnsupported

    var errorDescription: String? {
        switch self {
        case .localeUnsupported: return "O motor de voz da Apple não oferece português neste Mac."
        }
    }
}

/// Transcrição no próprio Mac com o motor de voz da Apple (SpeechAnalyzer).
enum Transcriber {
    static let preferredLocale = Locale(identifier: "pt-BR")

    /// Transcreve cada origem separadamente e intercala as falas pelo horário.
    static func transcribe(_ tracks: RecordedTracks) async throws -> [Segment] {
        var all: [Segment] = []
        if let mic = tracks.mic {
            all += try await transcribe(file: mic, speaker: "Eu", offset: tracks.micOffset)
        }
        if let system = tracks.system {
            all += try await transcribe(file: system, speaker: "Chamada", offset: tracks.systemOffset)
        }
        return all.sorted { $0.start < $1.start }
    }

    private static func transcribe(file: URL, speaker: String, offset: Double) async throws -> [Segment] {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: preferredLocale) else {
            throw TranscriberError.localeUnsupported
        }
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )

        // Na primeira vez o macOS baixa o modelo de português; depois é tudo offline.
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let collector = Task { () throws -> [Segment] in
            var segments: [Segment] = []
            for try await result in transcriber.results {
                let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                segments.append(Segment(start: result.range.start.seconds + offset, speaker: speaker, text: text))
            }
            return segments
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        do {
            let audio = try AVAudioFile(forReading: file)
            if let last = try await analyzer.analyzeSequence(from: audio) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            await analyzer.cancelAndFinishNow()
            collector.cancel()
            throw error
        }
        return try await collector.value
    }

    /// Markdown legível: falas seguidas da mesma pessoa viram um parágrafo só.
    static func markdown(_ segments: [Segment], title: String) -> String {
        var lines = ["# Transcrição — \(title)", ""]
        var current: Segment?
        func flush() {
            guard let c = current else { return }
            lines.append("**[\(timestamp(c.start))] \(c.speaker):** \(c.text)")
            lines.append("")
        }
        for segment in segments {
            if var c = current, c.speaker == segment.speaker, segment.start - c.start < 90 {
                c.text += " " + segment.text
                current = c
            } else {
                flush()
                current = segment
            }
        }
        flush()
        if segments.isEmpty {
            lines.append("_Nenhuma fala reconhecida._")
        }
        return lines.joined(separator: "\n")
    }

    static func timestamp(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
