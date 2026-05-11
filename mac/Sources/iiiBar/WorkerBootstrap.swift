import Foundation

final class WorkerBootstrap {
    private var process: Process?
    private var pipe: Pipe?

    var isRunning: Bool {
        process?.isRunning == true
    }

    func start(
        controlUrl: String,
        onOutput: @escaping @MainActor (String) -> Void,
        onExit: @escaping @MainActor (Int32) -> Void
    ) throws -> String {
        if ProcessInfo.processInfo.environment["IIIBAR_SKIP_WORKER_BOOTSTRAP"] == "1" {
            return "Worker bootstrap disabled"
        }
        if isRunning {
            return "iiibar-worker running"
        }
        guard let workerDirectory = resolveWorkerDirectory() else {
            throw BootstrapError.workerDirectoryMissing
        }
        let nodeModules = workerDirectory.appendingPathComponent("node_modules")
        guard FileManager.default.fileExists(atPath: nodeModules.path) else {
            throw BootstrapError.dependenciesMissing(workerDirectory.path)
        }
        let builtWorker = workerDirectory.appendingPathComponent("dist/index.js")
        guard FileManager.default.fileExists(atPath: builtWorker.path) else {
            throw BootstrapError.buildMissing(workerDirectory.path)
        }

        let nextPipe = Pipe()
        let nextProcess = Process()
        let pnpmPath = resolveExecutable("pnpm")
        nextProcess.executableURL = URL(fileURLWithPath: pnpmPath ?? "/usr/bin/env")
        nextProcess.arguments = pnpmPath == nil ? ["pnpm", "start"] : ["start"]
        nextProcess.currentDirectoryURL = workerDirectory
        nextProcess.standardOutput = nextPipe
        nextProcess.standardError = nextPipe

        var environment = ProcessInfo.processInfo.environment
        environment["IIIBAR_CONTROL_URL"] = controlUrl
        environment["FORCE_COLOR"] = "0"
        environment["PATH"] = [
            environment["PATH"],
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(NSHomeDirectory())/Library/pnpm",
        ]
            .compactMap { $0 }
            .joined(separator: ":")
        nextProcess.environment = environment

        nextPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
            Task { @MainActor in
                onOutput(text)
            }
        }

        nextProcess.terminationHandler = { process in
            Task { @MainActor in
                onOutput("iiibar-worker exited with code \(process.terminationStatus)")
                onExit(process.terminationStatus)
            }
        }

        try nextProcess.run()
        process = nextProcess
        pipe = nextPipe
        return "iiibar-worker starting from \(workerDirectory.path)"
    }

    func stop() {
        pipe?.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
        pipe = nil
    }

    private func resolveWorkerDirectory() -> URL? {
        var candidates: [URL] = []
        if let envPath = ProcessInfo.processInfo.environment["IIIBAR_WORKER_DIR"], !envPath.isEmpty {
            candidates.append(URL(fileURLWithPath: envPath))
        }
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        candidates.append(current.appendingPathComponent("../worker").standardizedFileURL)
        candidates.append(current.appendingPathComponent("worker").standardizedFileURL)
        if let executable = Bundle.main.executableURL {
            let executableDirectory = executable.deletingLastPathComponent()
            candidates.append(executableDirectory.appendingPathComponent("../../../../worker").standardizedFileURL)
            candidates.append(executableDirectory.appendingPathComponent("../../../../../worker").standardizedFileURL)
        }
        let sourceDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        candidates.append(sourceDirectory.appendingPathComponent("worker").standardizedFileURL)

        return candidates.first { candidate in
            FileManager.default.fileExists(atPath: candidate.appendingPathComponent("package.json").path)
        }
    }

    private func resolveExecutable(_ name: String) -> String? {
        let pathCandidates = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
            + [
                "/opt/homebrew/bin",
                "/usr/local/bin",
                "\(NSHomeDirectory())/Library/pnpm",
            ]

        return pathCandidates
            .map { URL(fileURLWithPath: $0).appendingPathComponent(name).path }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

enum BootstrapError: LocalizedError {
    case workerDirectoryMissing
    case dependenciesMissing(String)
    case buildMissing(String)

    var errorDescription: String? {
        switch self {
        case .workerDirectoryMissing:
            return "Could not find iiibar-worker. Set IIIBAR_WORKER_DIR to iii-experimental/iiibar/worker."
        case .dependenciesMissing(let path):
            return "iiibar-worker dependencies are missing. Run: cd \(path) && pnpm install"
        case .buildMissing(let path):
            return "iiibar-worker build is missing. Run: cd \(path) && pnpm build"
        }
    }
}
