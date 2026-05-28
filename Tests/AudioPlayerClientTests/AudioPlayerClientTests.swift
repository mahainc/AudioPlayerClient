import Testing
@testable import AudioPlayerClient

@Suite("AudioPlayerClient interface")
struct AudioPlayerClientTests {
    @Test("noop client never reports playing")
    func noopIsNotPlaying() async {
        let client = AudioPlayerClient.noop
        let playing = await client.isPlaying()
        #expect(playing == false)
    }

    @Test("noop play resolves without throwing")
    func noopPlayResolves() async throws {
        let client = AudioPlayerClient.noop
        try await client.play(.url(URL(string: "https://example.com/a.mp3")!))
    }

    @Test("Source equality discriminates url vs data")
    func sourceEquality() {
        let url = AudioPlayerClient.Source.url(URL(string: "https://example.com/a.mp3")!)
        let data = AudioPlayerClient.Source.data(Data([0x01]), mime: "audio/mpeg")
        #expect(url != data)
    }
}
