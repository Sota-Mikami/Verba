import Foundation
import os

private let logger = Logger(subsystem: "com.sotamikami.verba", category: "MediaControl")

/// Controls system media playback (Spotify, Music, YouTube, etc.) via MediaRemote private framework.
class MediaControlService {
    private var wasPlayingBeforePause = false

    // MediaRemote command constants
    private static let kMRPlay: UInt32 = 0
    private static let kMRPause: UInt32 = 1

    private typealias MRSendCommandFn = @convention(c) (UInt32, UnsafeRawPointer?) -> Bool
    private typealias MRGetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void

    private lazy var bundle: CFBundle? = {
        CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
    }()

    private func function<T>(named name: String) -> T? {
        guard let bundle,
              let pointer = CFBundleGetFunctionPointerForName(bundle, name as CFString) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    /// Check if any media is currently playing, then pause it. Remembers state for later resume.
    func pauseIfPlaying() async {
        let isPlaying = await checkIsPlaying()
        wasPlayingBeforePause = isPlaying
        if isPlaying {
            sendCommand(Self.kMRPause)
            logger.info("Paused system media for recording")
        }
    }

    /// Resume media only if we paused it earlier.
    func resumeIfPaused() {
        guard wasPlayingBeforePause else { return }
        wasPlayingBeforePause = false
        sendCommand(Self.kMRPlay)
        logger.info("Resumed system media after recording")
    }

    private func checkIsPlaying() async -> Bool {
        await withCheckedContinuation { continuation in
            guard let fn: MRGetNowPlayingInfoFn = function(named: "MRMediaRemoteGetNowPlayingInfo") else {
                continuation.resume(returning: false)
                return
            }
            fn(DispatchQueue.main) { info in
                let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
                continuation.resume(returning: rate > 0)
            }
        }
    }

    private func sendCommand(_ command: UInt32) {
        guard let fn: MRSendCommandFn = function(named: "MRMediaRemoteSendCommand") else {
            logger.warning("MediaRemote not available")
            return
        }
        _ = fn(command, nil)
    }
}
