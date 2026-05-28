import Dependencies
import Foundation

extension AudioPlayerClient: TestDependencyKey {
    /// Test value — unimplemented, fails if called without explicit override.
    public static let testValue = AudioPlayerClient()

    /// Preview value — silent no-op so previews don't try to play audio.
    public static let previewValue = AudioPlayerClient.noop
}

extension AudioPlayerClient {
    /// A no-op client that silently ignores all playback requests.
    public static let noop = AudioPlayerClient(
        play: { _ in },
        stop: {},
        isPlaying: { false }
    )
}

extension DependencyValues {
    public var audioPlayerClient: AudioPlayerClient {
        get { self[AudioPlayerClient.self] }
        set { self[AudioPlayerClient.self] = newValue }
    }
}
