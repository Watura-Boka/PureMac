
enum ProtectionCommand: CaseIterable, Hashable, Sendable {
    case gatekeeper
    case fileVault
    case firewall
    case systemIntegrityProtection

    var executableURL: URL {
        switch self {
        case .gatekeeper:
            return URL(fileURLWithPath: "/usr/sbin/spctl")
        case .fileVault:
            return URL(fileURLWithPath: "/usr/bin/fdesetup")
        case .firewall:
            return URL(fileURLWithPath: "/usr/libexec/ApplicationFirewall/socketfilterfw")
        case .systemIntegrityProtection:
            return URL(fileURLWithPath: "/usr/bin/csrutil")
        }
    }

    var arguments: [String] {
        switch self {
        case .gatekeeper:
            return ["--status"]
        case .fileVault:
            return ["status"]
        case .firewall:
            return ["--getglobalstate"]
        case .systemIntegrityProtection:
            return ["status"]
        }
    }

    var check: ProtectionCheck {
        switch self {
        case .gatekeeper:
            return .gatekeeper
        case .fileVault:
            return .fileVault
        case .firewall:
            return .firewall
        case .systemIntegrityProtection:
            return .systemIntegrityProtection
        }
    }
}

struct ProtectionCommandResult: Sendable, Equatable {
    let exitCode: Int32?
    let stdout: String
    let stderr: String
    let timedOut: Bool
    let cancelled: Bool
    let launchError: String?

    var succeeded: Bool {
        exitCode == 0 && !timedOut && !cancelled && launchError == nil
    }
}

struct ProtectionProcessRequest: Sendable {
    let executableURL: URL
    let arguments: [String]
}

private final class ProtectionOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private let limit = 65_536

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard data.count < limit else { return }
        data.append(chunk.prefix(limit - data.count))
    }

    func string() -> String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private final class ProtectionProcessController: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancellationRequested = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancellationRequested
    }

    func install(_ process: Process) {
        lock.lock()
        self.process = process
        let shouldStop = cancellationRequested
        lock.unlock()
        if shouldStop { stop(process) }
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let process = process
        lock.unlock()
        if let process { stop(process) }
    }

    private func stop(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        let processID = process.processIdentifier
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.25) {
            guard process.isRunning else { return }
            Darwin.kill(processID, SIGKILL)
        }
    }
}

enum ProtectionCommandRunner {
    static func run(
        _ command: ProtectionCommand,
        timeout: TimeInterval = 4
    ) async -> ProtectionCommandResult {
        await run(
            ProtectionProcessRequest(
                executableURL: command.executableURL,
                arguments: command.arguments
            ),
            timeout: timeout
        )
    }

    static func run(
        _ request: ProtectionProcessRequest,
        timeout: TimeInterval
    ) async -> ProtectionCommandResult {
        let controller = ProtectionProcessController()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    continuation.resume(
                        returning: runBlocking(
                            request,
                            timeout: max(timeout, 0),
                            controller: controller
                        )
                    )
                }
            }
        } onCancel: {
            controller.cancel()
        }
    }

    private static func runBlocking(
        _ request: ProtectionProcessRequest,
        timeout: TimeInterval,
        controller: ProtectionProcessController
    ) -> ProtectionCommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let exitSignal = DispatchSemaphore(value: 0)
        let readers = DispatchGroup()
        let output = ProtectionOutputBuffer()
        let errors = ProtectionOutputBuffer()

        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = FileHandle.nullDevice
        process.terminationHandler = { _ in exitSignal.signal() }
        controller.install(process)

        guard !controller.isCancelled else {
            return ProtectionCommandResult(
                exitCode: nil,
                stdout: "",
                stderr: "",
                timedOut: false,
                cancelled: true,
                launchError: nil
            )
        }

        do {
