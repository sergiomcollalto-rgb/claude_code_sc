import AVFoundation
import CoreMedia
import ScreenCaptureKit

/// Resultado de uma gravação: um arquivo por origem, com o atraso de cada um
/// em relação ao início da reunião (para alinhar as falas na transcrição).
struct RecordedTracks {
    var mic: URL?
    var micOffset: Double = 0
    var system: URL?
    var systemOffset: Double = 0
}

enum RecorderError: LocalizedError {
    case noDisplay
    case microphoneDenied
    case nothingRecorded

    var errorDescription: String? {
        switch self {
        case .noDisplay: return "Nenhuma tela encontrada para capturar o som da chamada."
        case .microphoneDenied: return "Sem permissão de microfone. Libere em Ajustes do Sistema > Privacidade e Segurança > Microfone."
        case .nothingRecorded: return "Nenhum áudio foi gravado."
        }
    }
}

/// Grava o microfone e o som do sistema (a chamada) em arquivos separados.
/// Usa um único SCStream para que as duas origens compartilhem o mesmo relógio.
final class Recorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private let queue = DispatchQueue(label: "relato.recorder")
    private var stream: SCStream?
    private var micWriter: TrackWriter?
    private var systemWriter: TrackWriter?

    func start(in folder: URL) async throws {
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            throw RecorderError.microphoneDenied
        }

        // Dispara o pedido de permissão de Gravação de Tela na primeira vez.
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw RecorderError.noDisplay }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.captureMicrophone = true
        config.sampleRate = 48_000
        config.channelCount = 2
        // O vídeo é obrigatório no SCStream, então fica no mínimo possível e é descartado.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.showsCursor = false

        micWriter = TrackWriter(url: folder.appendingPathComponent("mic.m4a"))
        systemWriter = TrackWriter(url: folder.appendingPathComponent("chamada.m4a"))

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async throws -> RecordedTracks {
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil

        // Garante que nenhum buffer ainda está sendo escrito.
        let (mic, system) = queue.sync { (micWriter, systemWriter) }
        micWriter = nil
        systemWriter = nil

        let micStart = await mic?.finish()
        let systemStart = await system?.finish()

        guard micStart != nil || systemStart != nil else { throw RecorderError.nothingRecorded }
        let origin = min(micStart ?? .infinity, systemStart ?? .infinity)

        var tracks = RecordedTracks()
        if let micStart, let mic {
            tracks.mic = mic.url
            tracks.micOffset = micStart - origin
        }
        if let systemStart, let system {
            tracks.system = system.url
            tracks.systemOffset = systemStart - origin
        }
        return tracks
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        switch type {
        case .audio: systemWriter?.append(sampleBuffer)
        case .microphone: micWriter?.append(sampleBuffer)
        default: break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("Relato: captura interrompida: \(error.localizedDescription)")
    }
}

/// Escreve uma origem de áudio em .m4a (AAC). Configura-se sozinho a partir
/// do formato do primeiro buffer que chegar.
private final class TrackWriter {
    let url: URL
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var startSeconds: Double?
    private var failed = false

    init(url: URL) {
        self.url = url
    }

    func append(_ buffer: CMSampleBuffer) {
        guard !failed else { return }
        if writer == nil {
            guard let format = CMSampleBufferGetFormatDescription(buffer),
                  let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee else { return }
            do {
                try? FileManager.default.removeItem(at: url)
                let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
                let channels = max(1, min(2, Int(asbd.mChannelsPerFrame)))
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: asbd.mSampleRate,
                    AVNumberOfChannelsKey: channels,
                ]
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings, sourceFormatHint: format)
                input.expectsMediaDataInRealTime = true
                writer.add(input)
                guard writer.startWriting() else {
                    throw writer.error ?? RecorderError.nothingRecorded
                }
                let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                writer.startSession(atSourceTime: pts)
                self.writer = writer
                self.input = input
                self.startSeconds = pts.seconds
            } catch {
                NSLog("Relato: não consegui iniciar \(url.lastPathComponent): \(error.localizedDescription)")
                failed = true
                return
            }
        }
        if let input, input.isReadyForMoreMediaData {
            input.append(buffer)
        }
    }

    /// Fecha o arquivo. Retorna o instante (em segundos do relógio da captura)
    /// do primeiro buffer, ou nil se nada foi gravado.
    func finish() async -> Double? {
        guard let writer, let input, let startSeconds, writer.status == .writing else { return nil }
        input.markAsFinished()
        await writer.finishWriting()
        return writer.status == .completed ? startSeconds : nil
    }
}

/// Junta microfone e chamada em um único arquivo de áudio.
enum AudioMixer {
    static func mix(_ tracks: RecordedTracks, to output: URL) async throws {
        let composition = AVMutableComposition()
        for (url, offset) in [(tracks.mic, tracks.micOffset), (tracks.system, tracks.systemOffset)] {
            guard let url else { continue }
            let asset = AVURLAsset(url: url)
            guard let source = try await asset.loadTracks(withMediaType: .audio).first else { continue }
            let duration = try await asset.load(.duration)
            let target = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try target?.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: source,
                at: CMTime(seconds: offset, preferredTimescale: 48_000)
            )
        }
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw RecorderError.nothingRecorded
        }
        try? FileManager.default.removeItem(at: output)
        try await export.export(to: output, as: .m4a)
    }
}
