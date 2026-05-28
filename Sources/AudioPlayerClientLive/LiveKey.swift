import AudioPlayerClient
import Dependencies
import Foundation
import OSLog

private let logger = Logger(subsystem: "AIChatbot", category: "AudioPlayer")

#if canImport(AVFoundation)
import AVFoundation

extension AudioPlayerClient: DependencyKey {
    public static let liveValue: AudioPlayerClient = {
        let engine = AudioEngine()

        return AudioPlayerClient(
            play: { source in
                try await engine.play(source)
            },
            stop: {
                await engine.stop()
            },
            isPlaying: {
                await engine.isPlaying
            }
        )
    }()
}

private actor AudioEngine {
    private var player: AVPlayer?
    private var continuation: CheckedContinuation<Void, Error>?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var sessionConfigured = false

    var isPlaying: Bool {
        guard let player else { return false }
        return player.timeControlStatus == .playing
    }

    func play(_ source: AudioPlayerClient.Source) async throws {
        // Cancel any in-flight playback.
        stopImmediately(error: CancellationError())

        configureSessionIfNeeded()

        let url: URL
        switch source {
        case .url(let remoteURL):
            url = remoteURL
            logger.info("play url=\(remoteURL.absoluteString, privacy: .public)")
        case .data(let data, let mime):
            url = try writeTempFile(data: data, mime: mime)
            logger.info("play data bytes=\(data.count) mime=\(mime, privacy: .public) tempURL=\(url.path, privacy: .public)")
        }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        self.player = player

        // Bridge AVPlayerItemDidPlayToEndTime → continuation resume.
        try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    self.continuation = cont
                    self.endObserver = NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: item,
                        queue: nil
                    ) { [weak self] _ in
                        logger.info("AVPlayerItemDidPlayToEndTime")
                        Task { await self?.finish() }
                    }
                    self.failureObserver = NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemFailedToPlayToEndTime,
                        object: item,
                        queue: nil
                    ) { [weak self] notification in
                        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                        logger.error("AVPlayerItemFailedToPlayToEndTime: \(error?.localizedDescription ?? "unknown", privacy: .public)")
                        Task { await self?.failPlayback(error: error ?? NSError(domain: "AudioPlayer", code: -1)) }
                    }
                    player.play()
                    logger.info("player.play() called, rate=\(player.rate, privacy: .public) status=\(player.status.rawValue)")
                }
            },
            onCancel: {
                Task { await self.stopImmediately(error: CancellationError()) }
            }
        )
    }

    func stop() {
        stopImmediately(error: CancellationError())
    }

    private func finish() {
        player?.pause()
        player = nil
        clearObserver()
        let cont = continuation
        continuation = nil
        cont?.resume()
    }

    private func failPlayback(error: Error) {
        player?.pause()
        player = nil
        clearObserver()
        let cont = continuation
        continuation = nil
        cont?.resume(throwing: error)
    }

    private func stopImmediately(error: Error) {
        player?.pause()
        player = nil
        clearObserver()
        let cont = continuation
        continuation = nil
        cont?.resume(throwing: error)
    }

    private func clearObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
            self.failureObserver = nil
        }
    }

    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: []
            )
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            logger.info("AVAudioSession configured: category=playback mode=spokenAudio")
        } catch {
            logger.error("AVAudioSession configure failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    private func writeTempFile(data: Data, mime: String) throws -> URL {
        let ext = Self.fileExtension(for: mime)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio_\(UUID().uuidString).\(ext)")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func fileExtension(for mime: String) -> String {
        let lower = mime.lowercased()
        if lower.contains("wav") { return "wav" }
        if lower.contains("aac") { return "aac" }
        if lower.contains("m4a") { return "m4a" }
        return "mp3"
    }
}

#else

extension AudioPlayerClient: DependencyKey {
    public static let liveValue = AudioPlayerClient.noop
}

#endif
