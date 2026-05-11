import Foundation

struct EngineProfile: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var kind: String
    var host: String
    var httpPort: Int
    var bridgePort: Int
    var streamPort: Int
    var binaryPath: String?
    var configPath: String?
    var workingDirectory: String?
    var env: [String: String]?
    var autoStart: Bool?
    var pollingIntervalSeconds: Int?
}

struct ProfileListResult: Codable {
    var profiles: [EngineProfile]
    var stateAvailable: Bool
    var warning: String?
}

struct HealthStatus: Codable {
    var status: String
    var version: String?
}

struct EngineStatus: Codable {
    var profile: EngineProfile
    var state: String
    var reachable: Bool
    var health: HealthStatus?
    var workers: Int
    var functions: Int
    var triggers: Int
    var components: [String: String]
    var checkedAt: String
    var message: String?
}

struct RuntimeEndpoint: Codable, Identifiable {
    var id: String { "\(label)-\(url)" }
    var label: String
    var url: String
    var available: Bool?
}

struct RuntimeResources: Codable {
    var metricsAvailable: Bool
    var workersWithMetrics: Int
    var cpuPercent: Double?
    var memoryRssBytes: Double?
    var memoryHeapUsedBytes: Double?
    var eventLoopLagMs: Double?
}

struct RuntimeWorker: Codable, Identifiable {
    var id: String
    var name: String
    var status: String
    var runtime: String?
    var version: String?
    var os: String?
    var pid: Int?
    var ipAddress: String?
    var isInternal: Bool
    var functionCount: Int
    var activeInvocations: Int
    var connectedAtMs: Double?
    var uptimeSeconds: Double?
    var memoryRssBytes: Double?
    var memoryHeapUsedBytes: Double?
    var cpuPercent: Double?
    var eventLoopLagMs: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case runtime
        case version
        case os
        case pid
        case ipAddress
        case isInternal = "internal"
        case functionCount
        case activeInvocations
        case connectedAtMs
        case uptimeSeconds
        case memoryRssBytes
        case memoryHeapUsedBytes
        case cpuPercent
        case eventLoopLagMs
    }
}

struct RuntimeSummary: Codable {
    var profile: EngineProfile
    var reachable: Bool
    var status: String
    var workerCount: Int
    var externalWorkerCount: Int
    var internalWorkerCount: Int
    var processCount: Int
    var functionCount: Int
    var triggerCount: Int
    var activeInvocations: Int
    var longestUptimeSeconds: Double?
    var endpoints: [RuntimeEndpoint]
    var workers: [RuntimeWorker]
    var runtimes: [String: Int]
    var locations: [String: Int]
    var resources: RuntimeResources
    var checkedAt: String
    var message: String?
}

struct InvocationMetrics: Codable {
    var total: Int
    var success: Int
    var error: Int
    var deferred: Int
    var byFunction: [String: Int]

    enum CodingKeys: String, CodingKey {
        case total
        case success
        case error
        case deferred
        case byFunction = "by_function"
    }
}

struct WorkerPoolMetrics: Codable {
    var spawns: Int
    var deaths: Int
    var active: Int
}

struct PerformanceMetrics: Codable {
    var avgDurationMs: Double
    var p50DurationMs: Double
    var p95DurationMs: Double
    var p99DurationMs: Double
    var minDurationMs: Double
    var maxDurationMs: Double

    enum CodingKeys: String, CodingKey {
        case avgDurationMs = "avg_duration_ms"
        case p50DurationMs = "p50_duration_ms"
        case p95DurationMs = "p95_duration_ms"
        case p99DurationMs = "p99_duration_ms"
        case minDurationMs = "min_duration_ms"
        case maxDurationMs = "max_duration_ms"
    }
}

struct TelemetrySummary: Codable {
    var profile: EngineProfile
    var available: Bool
    var invocations: InvocationMetrics
    var workers: WorkerPoolMetrics
    var performance: PerformanceMetrics
    var recentErrors: Int
    var recentWarnings: Int
    var errorTraces: Int
    var slowTraces: Int
    var alerts: Int
    var checkedAt: String
    var warning: String?
}

struct ProcessState: Codable {
    var profileId: String
    var running: Bool
    var pid: Int?
    var startedAt: String?
    var stoppedAt: String?
    var message: String?
}

struct LogsResponse: Codable {
    var logs: [OtelLog]?
    var total: Int?
}

struct OtelLog: Codable, Identifiable {
    var id: String { "\(timestampUnixNano ?? 0)-\(body ?? "")" }
    var timestampUnixNano: Int?
    var severityText: String?
    var body: String?
    var serviceName: String?

    enum CodingKeys: String, CodingKey {
        case timestampUnixNano = "timestamp_unix_nano"
        case severityText = "severity_text"
        case body
        case serviceName = "service_name"
    }
}

struct TracesResponse: Codable {
    var spans: [StoredSpan]?
    var total: Int?
}

struct StoredSpan: Codable, Identifiable {
    var id: String { spanId }
    var traceId: String
    var spanId: String
    var name: String
    var status: String?
    var serviceName: String?

    enum CodingKeys: String, CodingKey {
        case traceId = "trace_id"
        case spanId = "span_id"
        case name
        case status
        case serviceName = "service_name"
    }
}

struct DiagnosticsResult: Codable {
    var text: String
}
