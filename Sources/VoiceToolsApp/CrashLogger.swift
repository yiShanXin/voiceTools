import Foundation
import Darwin

private func voiceHubUncaughtExceptionHandler(_ exception: NSException) {
    CrashLogger.shared.handleUncaughtException(exception)
}

private func voiceHubSignalHandler(_ signal: Int32) {
    CrashLogger.shared.handleSignal(signal)
}

final class CrashLogger {
    static let shared = CrashLogger()

    private let fileManager = FileManager.default
    private let logDirURL: URL
    private let logFileURL: URL
    private let stateFileURL: URL
    private var signalFD: Int32 = -1
    private var installed = false
    private var handlingSignal = false

    private init() {
        let home = fileManager.homeDirectoryForCurrentUser
        logDirURL = home.appendingPathComponent("Library/Logs/VoiceHub", isDirectory: true)
        logFileURL = logDirURL.appendingPathComponent("crash.log", isDirectory: false)
        stateFileURL = logDirURL.appendingPathComponent("session.state", isDirectory: false)
    }

    func install() {
        guard !installed else { return }
        installed = true

        prepareLogDirectory()
        openSignalFD()
        recordUncleanShutdownIfNeeded()
        writeSessionState()
        append("=== Launch pid=\(getpid()) time=\(timestamp()) ===")

        NSSetUncaughtExceptionHandler(voiceHubUncaughtExceptionHandler)
        signal(SIGABRT, voiceHubSignalHandler)
        signal(SIGSEGV, voiceHubSignalHandler)
        signal(SIGBUS, voiceHubSignalHandler)
        signal(SIGILL, voiceHubSignalHandler)
        signal(SIGFPE, voiceHubSignalHandler)
        signal(SIGTRAP, voiceHubSignalHandler)
    }

    func markCleanExit() {
        append("=== Clean exit pid=\(getpid()) time=\(timestamp()) ===")
        try? fileManager.removeItem(at: stateFileURL)
    }

    func handleUncaughtException(_ exception: NSException) {
        append("UncaughtException name=\(exception.name.rawValue) reason=\(exception.reason ?? "nil")")
        let stack = exception.callStackSymbols.joined(separator: "\n")
        append("Stack:\n\(stack)")
    }

    func handleSignal(_ signal: Int32) {
        if handlingSignal { return }
        handlingSignal = true

        let msg = "SignalCrash signal=\(signal) pid=\(getpid()) time=\(timestamp())\n"
        writeSignalSafe(msg)
        markSignalInState(signal)

        Darwin.signal(signal, SIG_DFL)
        Darwin.raise(signal)
    }

    private func prepareLogDirectory() {
        try? fileManager.createDirectory(at: logDirURL, withIntermediateDirectories: true)
    }

    private func openSignalFD() {
        let path = (logFileURL.path as NSString).fileSystemRepresentation
        signalFD = Darwin.open(path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
    }

    private func append(_ line: String) {
        let text = line + "\n"
        guard let data = text.data(using: .utf8) else { return }
        if fileManager.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                return
            }
        }
        try? data.write(to: logFileURL, options: .atomic)
    }

    private func writeSignalSafe(_ line: String) {
        guard signalFD >= 0 else { return }
        line.withCString { ptr in
            _ = Darwin.write(signalFD, ptr, strlen(ptr))
        }
    }

    private func writeSessionState() {
        let state = "pid=\(getpid()) launch=\(timestamp())\n"
        try? state.write(to: stateFileURL, atomically: true, encoding: .utf8)
    }

    private func markSignalInState(_ signal: Int32) {
        let state = "pid=\(getpid()) signal=\(signal) crash=\(timestamp())\n"
        try? state.write(to: stateFileURL, atomically: true, encoding: .utf8)
    }

    private func recordUncleanShutdownIfNeeded() {
        guard let last = try? String(contentsOf: stateFileURL, encoding: .utf8),
              !last.isEmpty else {
            return
        }
        append("Previous session did not exit cleanly: \(last.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    private func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}
