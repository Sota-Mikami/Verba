import AVFoundation
import Combine

@MainActor
class AudioPlaybackService: ObservableObject {
    static let shared = AudioPlaybackService()

    @Published var playingRecordId: UUID?
    @Published var progress: Double = 0

    private var player: AVAudioPlayer?
    private var delegate: PlaybackDelegate?
    private var timer: Timer?

    func play(record: TranscriptionRecord) {
        stop()

        do {
            player = try AVAudioPlayer(data: record.wavData)
            let del = PlaybackDelegate { [weak self] in
                Task { @MainActor in self?.stop() }
            }
            self.delegate = del
            player?.delegate = del
            player?.play()
            playingRecordId = record.id

            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let player = self.player else { return }
                    self.progress = player.currentTime / max(player.duration, 0.01)
                }
            }
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        delegate = nil
        timer?.invalidate()
        timer = nil
        playingRecordId = nil
        progress = 0
    }

    func isPlaying(_ recordId: UUID) -> Bool {
        playingRecordId == recordId
    }
}

private class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
