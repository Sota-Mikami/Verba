import Foundation
import Sparkle

final class UpdateChecker: ObservableObject {
    @Published var canCheckForUpdates = false

    private var observation: NSKeyValueObservation?

    init(updater: SPUUpdater) {
        observation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, change in
            DispatchQueue.main.async {
                self?.canCheckForUpdates = change.newValue ?? false
            }
        }
    }
}
