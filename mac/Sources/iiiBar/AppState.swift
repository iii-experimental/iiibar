import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var profiles: [EngineProfile] = [AppState.defaultProfile]
    @Published var selectedProfileId: String?
    @Published var status: EngineStatus?
    @Published var telemetry: TelemetrySummary?
    @Published var runtime: RuntimeSummary?
    @Published var logs: LogsResponse?
    @Published var traces: TracesResponse?
    @Published var processState: ProcessState?
    @Published var errorMessage: String?
    @Published var workerMessage = "Starting iiibar-worker"
    @Published var workerRunning = false
    @Published var canCallIiiBarFunctions = false

    private let client: IiiFunctionClient
    private let workerBootstrap = WorkerBootstrap()
    private let controlUrl: String
    private var workerBootstrapAttempted = false

    init() {
        controlUrl = ProcessInfo.processInfo.environment["IIIBAR_CONTROL_URL"] ?? "ws://127.0.0.1:49134"
        client = IiiFunctionClient(url: URL(string: controlUrl)!)
        selectedProfileId = Self.defaultProfile.id
        setOfflineState("Waiting for iii Engine at \(controlUrl)")
        Task { await refreshAll() }
    }

    deinit {
        workerBootstrap.stop()
    }

    func refreshAll() async {
        await loadProfiles()
        if !canCallIiiBarFunctions {
            await ensureWorker()
            await loadProfiles()
        }
        if canCallIiiBarFunctions {
            await refreshSelected()
        }
    }

    var headerSubtitle: String {
        if let profile = selectedProfile {
            return "\(profile.name) - \(status?.state ?? "unknown")"
        }
        return errorMessage ?? workerMessage
    }

    var selectedProfile: EngineProfile? {
        profiles.first { $0.id == selectedProfileId } ?? profiles.first
    }

    var controlEndpoint: String {
        controlUrl
    }

    func restartWorker() async {
        workerBootstrap.stop()
        workerBootstrapAttempted = false
        await ensureWorker()
        await loadProfiles()
        if canCallIiiBarFunctions {
            await refreshSelected()
        }
    }

    func loadProfiles() async {
        do {
            let result = try await listProfilesWithRetry()
            profiles = result.profiles.isEmpty ? [Self.defaultProfile] : result.profiles
            selectedProfileId = profiles.contains { $0.id == selectedProfileId } ? selectedProfileId : profiles.first?.id
            canCallIiiBarFunctions = true
            workerRunning = true
            workerMessage = "iiibar-worker registered"
            errorMessage = result.warning
        } catch {
            canCallIiiBarFunctions = false
            let message = connectionMessage(error)
            errorMessage = message
            setOfflineState(message)
        }
    }

    func refreshSelected() async {
        guard canCallIiiBarFunctions, let profileId = selectedProfileId else { return }
        let payload = EncodablePayload(["profileId": profileId])
        async let statusTask: EngineStatus = client.invoke("iiibar::engines::status", payload: payload)
        async let telemetryTask: TelemetrySummary = client.invoke("iiibar::telemetry::summary", payload: payload)
        async let runtimeTask: RuntimeSummary = client.invoke("iiibar::runtime::summary", payload: payload)
        async let logsTask: LogsResponse = client.invoke("iiibar::logs::recent", payload: payload)
        async let tracesTask: TracesResponse = client.invoke("iiibar::traces::recent", payload: payload)

        do {
            status = try await statusTask
            telemetry = try await telemetryTask
            runtime = try await runtimeTask
            logs = try await logsTask
            traces = try await tracesTask
            errorMessage = nil
        } catch {
            let message = connectionMessage(error)
            errorMessage = message
            setOfflineState(message)
        }
    }

    func startSelected() async {
        guard canCallIiiBarFunctions else { return }
        await lifecycle("iiibar::engines::start")
    }

    func stopSelected() async {
        guard canCallIiiBarFunctions else { return }
        await lifecycle("iiibar::engines::stop")
    }

    func copyDiagnostics() async {
        guard canCallIiiBarFunctions, let profileId = selectedProfileId else { return }
        do {
            let result: DiagnosticsResult = try await client.invoke(
                "iiibar::diagnostics::copy",
                payload: EncodablePayload(["profileId": profileId])
            )
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result.text, forType: .string)
        } catch {
            errorMessage = connectionMessage(error)
        }
    }

    func quit() {
        workerMessage = "Quitting iiiBar"
        workerBootstrap.stop()
        Task {
            await client.disconnect()
            await MainActor.run {
                NSApp.terminate(nil)
            }
        }
    }

    private func lifecycle(_ functionId: String) async {
        guard canCallIiiBarFunctions, let profileId = selectedProfileId else { return }
        do {
            processState = try await client.invoke(functionId, payload: EncodablePayload(["profileId": profileId]))
            await refreshSelected()
        } catch {
            errorMessage = connectionMessage(error)
        }
    }

    private func ensureWorker() async {
        guard !workerBootstrapAttempted else { return }
        workerBootstrapAttempted = true
        do {
            workerMessage = try workerBootstrap.start(
                controlUrl: controlUrl,
                onOutput: { [weak self] output in
                    self?.workerMessage = output
                },
                onExit: { [weak self] code in
                    self?.workerRunning = false
                    self?.workerMessage = "iiibar-worker exited with code \(code)"
                }
            )
            workerRunning = workerBootstrap.isRunning
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        } catch {
            workerRunning = false
            workerMessage = error.localizedDescription
        }
    }

    private func listProfilesWithRetry() async throws -> ProfileListResult {
        var lastError: Error?
        for attempt in 0..<8 {
            do {
                return try await client.invoke("iiibar::profiles::list")
            } catch {
                lastError = error
                if !shouldRetryFunctionBootstrap(error) || attempt == 7 {
                    throw error
                }
                workerMessage = "Waiting for iiibar-worker registration"
                try? await Task.sleep(nanoseconds: 650_000_000)
            }
        }
        throw lastError ?? IiiFunctionClient.ClientError.timeout("iiibar::profiles::list")
    }

    private func shouldRetryFunctionBootstrap(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("function") || message.contains("not found") || message.contains("timed out")
    }

    private func connectionMessage(_ error: Error) -> String {
        let detail = error.localizedDescription
        if workerRunning {
            return "\(detail). Check that iii Engine is running at \(controlUrl)."
        }
        return "\(detail). \(workerMessage)"
    }

    private func setOfflineState(_ message: String) {
        let profile = selectedProfile ?? Self.defaultProfile
        if profiles.isEmpty {
            profiles = [profile]
            selectedProfileId = profile.id
        }
        status = EngineStatus(
            profile: profile,
            state: "unreachable",
            reachable: false,
            health: nil,
            workers: 0,
            functions: 0,
            triggers: 0,
            components: ["control": "unreachable"],
            checkedAt: ISO8601DateFormatter().string(from: Date()),
            message: message
        )
        telemetry = Self.emptyTelemetry(profile: profile, warning: message)
        runtime = Self.emptyRuntime(profile: profile, message: message)
        logs = LogsResponse(logs: [], total: 0)
        traces = TracesResponse(spans: [], total: 0)
    }

    private static let defaultProfile = EngineProfile(
        id: "local-default",
        name: "Local iii Engine",
        kind: "local",
        host: "127.0.0.1",
        httpPort: 3111,
        bridgePort: 49134,
        streamPort: 3112,
        binaryPath: nil,
        configPath: nil,
        workingDirectory: nil,
        env: nil,
        autoStart: false,
        pollingIntervalSeconds: 5
    )

    private static func emptyTelemetry(profile: EngineProfile, warning: String) -> TelemetrySummary {
        TelemetrySummary(
            profile: profile,
            available: false,
            invocations: InvocationMetrics(total: 0, success: 0, error: 0, deferred: 0, byFunction: [:]),
            workers: WorkerPoolMetrics(spawns: 0, deaths: 0, active: 0),
            performance: PerformanceMetrics(
                avgDurationMs: 0,
                p50DurationMs: 0,
                p95DurationMs: 0,
                p99DurationMs: 0,
                minDurationMs: 0,
                maxDurationMs: 0
            ),
            recentErrors: 0,
            recentWarnings: 0,
            errorTraces: 0,
            slowTraces: 0,
            alerts: 0,
            checkedAt: ISO8601DateFormatter().string(from: Date()),
            warning: warning
        )
    }

    private static func emptyRuntime(profile: EngineProfile, message: String) -> RuntimeSummary {
        RuntimeSummary(
            profile: profile,
            reachable: false,
            status: "unreachable",
            workerCount: 0,
            externalWorkerCount: 0,
            internalWorkerCount: 0,
            processCount: 0,
            functionCount: 0,
            triggerCount: 0,
            activeInvocations: 0,
            longestUptimeSeconds: nil,
            endpoints: [
                RuntimeEndpoint(label: "engine ws", url: "ws://\(profile.host):\(profile.bridgePort)", available: false),
                RuntimeEndpoint(label: "rest", url: "http://\(profile.host):\(profile.httpPort)", available: false),
                RuntimeEndpoint(label: "stream", url: "ws://\(profile.host):\(profile.streamPort)", available: false),
                RuntimeEndpoint(label: "console", url: "http://\(profile.host):3113", available: nil)
            ],
            workers: [],
            runtimes: [:],
            locations: [:],
            resources: RuntimeResources(
                metricsAvailable: false,
                workersWithMetrics: 0,
                cpuPercent: nil,
                memoryRssBytes: nil,
                memoryHeapUsedBytes: nil,
                eventLoopLagMs: nil
            ),
            checkedAt: ISO8601DateFormatter().string(from: Date()),
            message: message
        )
    }
}
