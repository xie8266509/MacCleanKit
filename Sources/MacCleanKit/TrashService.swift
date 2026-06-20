import AppKit
import Foundation

enum TrashService {
    @MainActor
    static func moveToTrash(_ urls: [URL]) async throws {
        guard !urls.isEmpty else { return }
        try PathSafety.validateTrashTargets(urls)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.recycle(urls) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
