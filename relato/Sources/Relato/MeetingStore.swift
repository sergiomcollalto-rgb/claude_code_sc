import AppKit
import Foundation

enum Stage: String, Codable {
    case recording, transcribing, writing, done, failed

    var label: String {
        switch self {
        case .recording: return "Gravando"
        case .transcribing: return "Transcrevendo"
        case .writing: return "Escrevendo ata"
        case .done: return "Ata pronta"
        case .failed: return "Erro"
        }
    }

    var isBusy: Bool { self == .recording || self == .transcribing || self == .writing }
}

struct Meeting: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    var title = "Reunião sem título"
    var duration: Double = 0
    var stage: Stage = .recording
    var error: String?
    /// Nome da pasta da reunião; vem do disco, não do meta.json.
    var folderName = ""

    enum CodingKeys: String, CodingKey { case id, date, title, duration, stage, error }
}

@MainActor
final class MeetingStore: ObservableObject {
    @Published var meetings: [Meeting] = []
    @Published var selection: Meeting.ID?
    @Published var root: URL
    @Published var recordingID: Meeting.ID?
    @Published var alert: String?

    private let recorder = Recorder()
    private static let rootKey = "pastaDasReunioes"

    var isRecording: Bool { recordingID != nil }
    var recordingStart: Date? { meetings.first { $0.id == recordingID }?.date }

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.rootKey) {
            root = URL(fileURLWithPath: saved)
        } else {
            root = Self.defaultRoot()
        }
        load()
    }

    // MARK: Pasta

    /// Pasta "Reuniões" dentro do Google Drive para computador, se estiver instalado.
    static func defaultRoot() -> URL {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let cloud = home.appendingPathComponent("Library/CloudStorage")
        let drives = (try? fm.contentsOfDirectory(at: cloud, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix("GoogleDrive") } ?? []
        for drive in drives {
            for name in ["Meu Drive", "My Drive"] {
                let myDrive = drive.appendingPathComponent(name)
                if fm.fileExists(atPath: myDrive.path) {
                    return myDrive.appendingPathComponent("Reuniões")
                }
            }
        }
        return home.appendingPathComponent("Documents/Reuniões")
    }

    var rootIsOnDrive: Bool { root.path.contains("/CloudStorage/GoogleDrive") }

    func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Usar esta pasta"
        panel.message = "Escolha onde salvar ata, transcrição e áudio (ex.: uma pasta do Google Drive)."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        root = url
        UserDefaults.standard.set(url.path, forKey: Self.rootKey)
        load()
    }

    func folder(of meeting: Meeting) -> URL { root.appendingPathComponent(meeting.folderName) }

    func text(_ file: String, of meeting: Meeting) -> String? {
        try? String(contentsOf: folder(of: meeting).appendingPathComponent(file), encoding: .utf8)
    }

    // MARK: Disco

    func load() {
        let fm = FileManager.default
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let folders = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        var loaded: [Meeting] = []
        for folder in folders {
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("meta.json")),
                  var meeting = try? decoder.decode(Meeting.self, from: data) else { continue }
            meeting.folderName = folder.lastPathComponent
            if meeting.stage.isBusy && meeting.id != recordingID {
                meeting.stage = .failed
                meeting.error = "O app foi fechado antes de terminar esta reunião."
            }
            loaded.append(meeting)
        }
        meetings = loaded.sorted { $0.date > $1.date }
    }

    private func save(_ meeting: Meeting) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(meeting) else { return }
        try? data.write(to: folder(of: meeting).appendingPathComponent("meta.json"))
    }

    private func update(_ id: Meeting.ID, _ change: (inout Meeting) -> Void) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }
        change(&meetings[index])
        save(meetings[index])
    }

    func trash(_ meeting: Meeting) {
        guard !meeting.stage.isBusy else { return }
        try? FileManager.default.trashItem(at: folder(of: meeting), resultingItemURL: nil)
        meetings.removeAll { $0.id == meeting.id }
        if selection == meeting.id { selection = nil }
    }

    // MARK: Gravação

    func toggleRecording() {
        Task {
            if isRecording { await stopRecording() } else { await startRecording() }
        }
    }

    private func startRecording() async {
        var meeting = Meeting()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH'h'mm'm'ss"
        meeting.folderName = formatter.string(from: meeting.date)
        let folder = folder(of: meeting)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try await recorder.start(in: folder)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            alert = "Não consegui começar a gravar.\n\n\(error.localizedDescription)\n\nSe for a primeira vez: libere o Relato em Ajustes do Sistema > Privacidade e Segurança > Gravação de Tela e Áudio do Sistema, e abra o app de novo."
            return
        }
        meetings.insert(meeting, at: 0)
        save(meeting)
        recordingID = meeting.id
        selection = meeting.id
    }

    private func stopRecording() async {
        guard let id = recordingID, let meeting = meetings.first(where: { $0.id == id }) else { return }
        recordingID = nil
        update(id) {
            $0.duration = Date().timeIntervalSince(meeting.date)
            $0.stage = .transcribing
        }
        let folder = folder(of: meeting)

        do {
            let tracks = try await recorder.stop()

            // Áudio único primeiro: mesmo que a transcrição falhe, a gravação fica salva.
            let mixed: Bool
            do {
                try await AudioMixer.mix(tracks, to: folder.appendingPathComponent("audio.m4a"))
                mixed = true
            } catch {
                mixed = false
            }

            let segments = try await Transcriber.transcribe(tracks)
            let transcript = Transcriber.markdown(segments, title: Self.dateLabel(meeting.date))
            try transcript.write(to: folder.appendingPathComponent("transcricao.md"), atomically: true, encoding: .utf8)
            if mixed {
                for url in [tracks.mic, tracks.system].compactMap({ $0 }) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            guard !segments.isEmpty else {
                update(id) {
                    $0.stage = .failed
                    $0.error = "Nenhuma fala foi reconhecida no áudio. O áudio ficou salvo na pasta."
                }
                return
            }
            await writeMinutes(for: id)
        } catch {
            update(id) {
                $0.stage = .failed
                $0.error = error.localizedDescription
            }
        }
    }

    /// Gera (ou refaz) a ata a partir da transcrição já salva.
    func writeMinutes(for id: Meeting.ID) async {
        guard let meeting = meetings.first(where: { $0.id == id }),
              let transcript = text("transcricao.md", of: meeting) else { return }
        update(id) {
            $0.stage = .writing
            $0.error = nil
        }
        do {
            let ata = try await MinutesWriter.write(transcript: transcript, date: meeting.date)
            try ata.write(to: folder(of: meeting).appendingPathComponent("ata.md"), atomically: true, encoding: .utf8)
            let title = MinutesWriter.title(from: ata)
            update(id) {
                $0.stage = .done
                if let title { $0.title = title }
            }
            if let title { rename(id, title: title) }
        } catch {
            update(id) {
                $0.stage = .failed
                $0.error = error.localizedDescription
            }
        }
    }

    /// Coloca o título no nome da pasta, para ficar fácil de achar no Drive.
    private func rename(_ id: Meeting.ID, title: String) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }
        let meeting = meetings[index]
        let safe = title
            .components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH'h'mm"
        let newName = "\(formatter.string(from: meeting.date)) - \(safe.prefix(80))"
        guard newName != meeting.folderName else { return }
        let target = root.appendingPathComponent(newName)
        guard !FileManager.default.fileExists(atPath: target.path) else { return }
        do {
            try FileManager.default.moveItem(at: folder(of: meeting), to: target)
            meetings[index].folderName = newName
        } catch {
            // A pasta mantém o nome antigo; nada se perde.
        }
    }

    static func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d 'de' MMMM 'de' yyyy, HH:mm"
        return formatter.string(from: date)
    }
}
