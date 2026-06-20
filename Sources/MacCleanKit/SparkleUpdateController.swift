import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
final class SparkleUpdateController: NSObject {
    static let shared = SparkleUpdateController()

    #if canImport(Sparkle)
    private var controller: SPUStandardUpdaterController?
    #endif

    var isConfigured: Bool {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String != nil
    }

    func startIfConfigured() {
        guard isConfigured else { return }
        #if canImport(Sparkle)
        guard controller == nil else { return }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        #endif
    }

    func checkForUpdates() {
        startIfConfigured()
        #if canImport(Sparkle)
        controller?.checkForUpdates(nil)
        #endif
    }
}
