import Foundation

struct ProcessRunResult: Sendable {
    let output: String
    let status: Int32
    let timedOut: Bool
}

enum ProcessRunner {
    static func run(_ executable: String, arguments: [String], timeout: TimeInterval = 10) -> ProcessRunResult {
        let process = Process()
        let pipe = Pipe()
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var didTimeOut = false

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        do {
            try process.run()
        } catch {
            return ProcessRunResult(output: error.localizedDescription, status: -1, timedOut: false)
        }

        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            didTimeOut = true
            process.terminate()
            _ = semaphore.wait(timeout: .now() + 2)
            if process.isRunning {
                process.interrupt()
            }
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var output = String(data: data, encoding: .utf8) ?? ""
        if didTimeOut {
            output += output.isEmpty ? "Timed out after \(Int(timeout))s" : "\nTimed out after \(Int(timeout))s"
        }

        return ProcessRunResult(
            output: output,
            status: didTimeOut ? 124 : process.terminationStatus,
            timedOut: didTimeOut
        )
    }
}
