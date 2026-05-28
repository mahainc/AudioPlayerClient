import Dependencies
import DependenciesMacros
import Foundation

/// A dependency client for playing audio from a remote URL or in-memory bytes.
///
/// Pairs naturally with server-side TTS that returns either a streamable URL
/// or base64-encoded audio. Consumers map their own audio payload (e.g.
/// `WasmClient.TTSAudio`) onto `AudioPlayerClient.Source` before calling `play`.
///
/// Usage:
/// ```swift
/// @Dependency(\.audioPlayerClient) var audioPlayerClient
///
/// return .run { [audioPlayerClient] _ in
///     try await audioPlayerClient.play(.url(url))
/// }
/// .cancellable(id: CancelID.audio, cancelInFlight: true)
/// ```
@DependencyClient
public struct AudioPlayerClient: Sendable {
    /// Play the given source. Resolves when playback completes naturally.
    /// Throws `CancellationError` if the calling task is cancelled — pair
    /// the call with `.cancellable(id:cancelInFlight:)` for stop-on-retap.
    public var play: @Sendable (_ source: Source) async throws -> Void

    /// Stop any in-flight playback immediately. Idempotent.
    public var stop: @Sendable () async -> Void = {}

    /// Whether audio is currently playing.
    public var isPlaying: @Sendable () async -> Bool = { false }
}

extension AudioPlayerClient {
    /// What to play. Mirrors the shape returned by server-side TTS actions
    /// (e.g. `WasmClient.TTSAudio`) so callers can map case-for-case.
    public enum Source: Sendable, Equatable {
        /// Streamable remote audio.
        case url(URL)
        /// Inline audio bytes plus a MIME hint (`"audio/mpeg"`, `"wav"`,
        /// `"mp3"`, etc.). The live impl writes these to a temp file before
        /// playback; the file extension is inferred from the mime string.
        case data(Data, mime: String)
    }
}
