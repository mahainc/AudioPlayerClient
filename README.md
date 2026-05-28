# AudioPlayerClient

A small TCA dependency client for playing audio from a remote URL or in-memory bytes. Pairs naturally with server-side TTS that returns either a streamable URL or base64-encoded audio. Built on [`swift-composable-architecture`](https://github.com/pointfreeco/swift-composable-architecture) and `AVFoundation`.

The package ships two products:

- **`AudioPlayerClient`** — interface only. No `AVFoundation` import, safe for tests and previews.
- **`AudioPlayerClientLive`** — wraps an internal `actor AudioEngine` around `AVPlayer` and registers the live `DependencyKey`.

## Installation

In your `Package.swift`:

```swift
.package(url: "https://github.com/mahainc/AudioPlayerClient.git", from: "0.1.0"),
```

Add `AudioPlayerClient` to your feature target and `AudioPlayerClientLive` to your app target.

## Usage

```swift
import AudioPlayerClient
import ComposableArchitecture

@Reducer
struct PlaybackFeature {
    @ObservableState
    struct State { var isPlaying = false }

    enum Action { case playTapped(URL), stopped }

    @Dependency(\.audioPlayerClient) var audioPlayerClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .playTapped(url):
                state.isPlaying = true
                return .run { send in
                    try await audioPlayerClient.play(.url(url))
                    await send(.stopped)
                }
                .cancellable(id: CancelID.audio, cancelInFlight: true)
            case .stopped:
                state.isPlaying = false
                return .none
            }
        }
    }

    enum CancelID { case audio }
}
```

## Source variants

```swift
// Streamable URL (most common for TTS):
try await audioPlayerClient.play(.url(remoteURL))

// Inline bytes plus a MIME hint — the live impl writes a temp file
// before playback; the extension is inferred from the mime string.
try await audioPlayerClient.play(.data(audioData, mime: "audio/mpeg"))
```

## Stopping playback

`stop()` is idempotent and safe to call from any context:

```swift
await audioPlayerClient.stop()
```

Or rely on cancellation — `.cancellable(id:cancelInFlight:)` will trigger the live actor's `CancellationError` path on retap.

## Testing

The interface module ships a `noop` factory for previews and `testValue` for `TestStore`:

```swift
let store = TestStore(initialState: PlaybackFeature.State()) {
    PlaybackFeature()
} withDependencies: {
    $0.audioPlayerClient = .noop
}
```

`testValue` uses the macro-generated unimplemented defaults — override `play`, `stop`, or `isPlaying` to assert on individual closures.

## License

MIT — see [LICENSE](./LICENSE).
