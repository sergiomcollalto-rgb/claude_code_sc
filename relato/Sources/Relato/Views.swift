import AppKit
import SwiftUI

enum Theme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let panel = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let raised = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let line = Color.white.opacity(0.08)
    static let accent = Color(red: 0.85, green: 1.0, blue: 0.31)
    static let danger = Color(red: 1.0, green: 0.36, blue: 0.33)
    static let muted = Color.white.opacity(0.5)
}

struct RootView: View {
    @EnvironmentObject var store: MeetingStore

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 290)
                .background(Theme.panel)
            Rectangle().fill(Theme.line).frame(width: 1)
            Group {
                if let meeting = store.meetings.first(where: { $0.id == store.selection }) {
                    MeetingDetail(meeting: meeting)
                } else {
                    EmptyState()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .alert("Relato", isPresented: Binding(get: { store.alert != nil }, set: { if !$0 { store.alert = nil } })) {
            Button("OK") { store.alert = nil }
        } message: {
            Text(store.alert ?? "")
        }
    }
}

// MARK: - Barra lateral

struct Sidebar: View {
    @EnvironmentObject var store: MeetingStore
    @State private var query = ""

    private var filtered: [Meeting] {
        guard !query.isEmpty else { return store.meetings }
        return store.meetings.filter { meeting in
            meeting.title.localizedCaseInsensitiveContains(query)
                || (store.text("ata.md", of: meeting)?.localizedCaseInsensitiveContains(query) ?? false)
                || (store.text("transcricao.md", of: meeting)?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Relato")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 18)

            RecordButton()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("Buscar em tudo que foi dito", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 8))

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filtered) { meeting in
                        MeetingRow(meeting: meeting, selected: meeting.id == store.selection)
                            .onTapGesture { store.selection = meeting.id }
                            .contextMenu {
                                Button("Mostrar no Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([store.folder(of: meeting)])
                                }
                                Button("Mover para o Lixo", role: .destructive) { store.trash(meeting) }
                                    .disabled(meeting.stage.isBusy)
                            }
                    }
                }
            }

            Button(action: store.chooseRoot) {
                HStack(spacing: 8) {
                    Image(systemName: store.rootIsOnDrive ? "checkmark.icloud.fill" : "folder.fill")
                        .foregroundStyle(store.rootIsOnDrive ? Theme.accent : Theme.muted)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.rootIsOnDrive ? "Salvando no Google Drive" : "Salvando só neste Mac")
                            .font(.system(size: 11, weight: .semibold))
                        Text(store.root.lastPathComponent + " · trocar pasta")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 16)
    }
}

struct RecordButton: View {
    @EnvironmentObject var store: MeetingStore

    var body: some View {
        Button(action: store.toggleRecording) {
            HStack(spacing: 10) {
                if store.isRecording, let start = store.recordingStart {
                    Image(systemName: "stop.fill")
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("Parar · " + Transcriber.timestamp(context.date.timeIntervalSince(start)))
                            .monospacedDigit()
                    }
                } else {
                    Image(systemName: "record.circle")
                    Text("Nova reunião")
                }
                Spacer()
                Text("⌘N").font(.system(size: 10, weight: .medium)).opacity(0.6)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(store.isRecording ? Color.white : Color.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(store.isRecording ? Theme.danger : Theme.accent, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct MeetingRow: View {
    let meeting: Meeting
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(meeting.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(Self.format(meeting.date))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            StageDot(stage: meeting.stage)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(selected ? Theme.raised : .clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "'Hoje,' HH:mm" : "d MMM, HH:mm"
        return formatter.string(from: date)
    }
}

struct StageDot: View {
    let stage: Stage

    var body: some View {
        switch stage {
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent).font(.system(size: 12))
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.danger).font(.system(size: 11))
        case .recording:
            Circle().fill(Theme.danger).frame(width: 8, height: 8)
        case .transcribing, .writing:
            ProgressView().controlSize(.mini)
        }
    }
}

// MARK: - Detalhe

struct MeetingDetail: View {
    @EnvironmentObject var store: MeetingStore
    let meeting: Meeting
    @State private var tab = 0
    @State private var copied = false

    private var file: String { tab == 0 ? "ata.md" : "transcricao.md" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(meeting.title)
                    .font(.system(size: 26, weight: .bold))
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Text(MeetingStore.dateLabel(meeting.date))
                    if meeting.duration > 0 {
                        Text("·")
                        Text(Transcriber.timestamp(meeting.duration))
                    }
                    StageChip(stage: meeting.stage)
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 36)
            .padding(.top, 30)

            HStack(spacing: 8) {
                TabButton(title: "Ata", active: tab == 0) { tab = 0 }
                TabButton(title: "Transcrição", active: tab == 1) { tab = 1 }
                Spacer()
                if meeting.stage == .done || meeting.stage == .failed {
                    ToolButton(icon: copied ? "checkmark" : "doc.on.doc", title: copied ? "Copiado" : "Copiar") {
                        guard let text = store.text(file, of: meeting) else { return }
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            copied = false
                        }
                    }
                    if store.text("transcricao.md", of: meeting) != nil {
                        ToolButton(icon: "arrow.clockwise", title: "Refazer ata") {
                            Task { await store.writeMinutes(for: meeting.id) }
                        }
                    }
                }
                ToolButton(icon: "folder", title: "Abrir pasta") {
                    NSWorkspace.shared.open(store.folder(of: meeting))
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 18)

            Rectangle().fill(Theme.line).frame(height: 1)

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let text = store.text(file, of: meeting), !(tab == 0 && meeting.stage == .writing) {
            ScrollView {
                MarkdownView(text: text)
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 26)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(file + meeting.id.uuidString)
        } else {
            VStack(spacing: 14) {
                switch meeting.stage {
                case .recording:
                    PulsingDot()
                    Text("Gravando seu microfone e o som da chamada").font(.system(size: 15, weight: .semibold))
                    Text("Quando acabar, clique em Parar. A ata sai sozinha.").foregroundStyle(Theme.muted)
                case .transcribing:
                    ProgressView()
                    Text("Transcrevendo no seu Mac").font(.system(size: 15, weight: .semibold))
                    Text("Sem internet. Reuniões longas levam alguns minutos.").foregroundStyle(Theme.muted)
                case .writing:
                    ProgressView()
                    Text("O Claude está escrevendo a ata").font(.system(size: 15, weight: .semibold))
                    Text("Separando por assunto, decisões e tarefas.").foregroundStyle(Theme.muted)
                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 26)).foregroundStyle(Theme.danger)
                    Text("Algo deu errado").font(.system(size: 15, weight: .semibold))
                    Text(meeting.error ?? "Erro desconhecido.")
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                        .textSelection(.enabled)
                case .done:
                    Text("Arquivo não encontrado na pasta.").foregroundStyle(Theme.muted)
                }
            }
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct StageChip: View {
    let stage: Stage

    var body: some View {
        let color = stage == .done ? Theme.accent : stage == .failed || stage == .recording ? Theme.danger : Color.white
        Text(stage.label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }
}

struct TabButton: View {
    let title: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? Color.black : Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(active ? Theme.accent : Theme.raised, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ToolButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PulsingDot: View {
    @State private var on = false

    var body: some View {
        Circle()
            .fill(Theme.danger)
            .frame(width: 18, height: 18)
            .scaleEffect(on ? 1.25 : 0.85)
            .opacity(on ? 1 : 0.55)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

struct EmptyState: View {
    @EnvironmentObject var store: MeetingStore

    var body: some View {
        VStack(spacing: 28) {
            Text("Entre na chamada e aperte ⌘N")
                .font(.system(size: 24, weight: .bold))
            HStack(spacing: 14) {
                Step(icon: "record.circle", title: "1 · Grava", text: "Seu microfone e o som do Meet, Zoom, Teams ou WhatsApp.")
                Step(icon: "waveform", title: "2 · Transcreve", text: "No próprio Mac, com o motor de voz da Apple.")
                Step(icon: "checklist", title: "3 · Escreve a ata", text: "O Claude separa por assunto, decisões e tarefas.")
            }
            Text(store.rootIsOnDrive ? "Tudo vai direto para o seu Google Drive." : "Tudo fica salvo em \(store.root.path).")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
        }
        .padding(40)
    }
}

struct Step: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 22)).foregroundStyle(Theme.accent)
            Text(title).font(.system(size: 13, weight: .bold))
            Text(text).font(.system(size: 12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 200, height: 150, alignment: .topLeading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
    }
}

// MARK: - Markdown

/// Renderizador simples, linha a linha, para o formato da ata e da transcrição.
struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, raw in
                line(raw.trimmingCharacters(in: .whitespaces))
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func line(_ line: String) -> some View {
        if line.isEmpty {
            EmptyView()
        } else if line.hasPrefix("### ") {
            Text(inline(String(line.dropFirst(4))))
                .font(.system(size: 14, weight: .bold))
                .padding(.top, 8)
        } else if line.hasPrefix("## ") {
            Text(String(line.dropFirst(3)).uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(Theme.accent)
                .padding(.top, 18)
        } else if line.hasPrefix("# ") {
            EmptyView() // o título já aparece no cabeçalho
        } else if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") {
            bullet(icon: line.hasPrefix("- [x] ") ? "checkmark.square.fill" : "square", text: String(line.dropFirst(6)))
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            bullet(icon: nil, text: String(line.dropFirst(2)))
        } else {
            Text(inline(line)).font(.system(size: 13)).lineSpacing(4)
        }
    }

    private func bullet(icon: String?, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            if let icon {
                Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Theme.accent)
            } else {
                Text("•").foregroundStyle(Theme.muted)
            }
            Text(inline(text)).font(.system(size: 13)).lineSpacing(4)
        }
    }

    private func inline(_ string: String) -> AttributedString {
        (try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(string)
    }
}
