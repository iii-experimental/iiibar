import XCTest
@testable import iiiBar

final class ModelDecodingTests: XCTestCase {
    func testProfileListDecodes() throws {
        let data = Data("""
        {
          "profiles": [
            {
              "id": "local-default",
              "name": "Local iii",
              "kind": "local",
              "host": "127.0.0.1",
              "httpPort": 3111,
              "bridgePort": 49134,
              "streamPort": 3112
            }
          ],
          "stateAvailable": true
        }
        """.utf8)

        let result = try JSONDecoder().decode(ProfileListResult.self, from: data)
        XCTAssertEqual(result.profiles.first?.name, "Local iii")
        XCTAssertTrue(result.stateAvailable)
    }

    func testEngineStatusDecodes() throws {
        let data = Data("""
        {
          "profile": {
            "id": "local-default",
            "name": "Local iii",
            "kind": "local",
            "host": "127.0.0.1",
            "httpPort": 3111,
            "bridgePort": 49134,
            "streamPort": 3112
          },
          "state": "healthy",
          "reachable": true,
          "workers": 2,
          "functions": 8,
          "triggers": 3,
          "components": { "otel": "healthy" },
          "checkedAt": "2026-05-11T00:00:00.000Z"
        }
        """.utf8)

        let result = try JSONDecoder().decode(EngineStatus.self, from: data)
        XCTAssertEqual(result.state, "healthy")
        XCTAssertEqual(result.workers, 2)
        XCTAssertEqual(result.components["otel"], "healthy")
    }

    func testStatusColorFallbacks() {
        XCTAssertNotNil(statusColor("healthy"))
        XCTAssertNotNil(statusColor("degraded"))
        XCTAssertNotNil(statusColor("unreachable"))
        XCTAssertNotNil(statusColor("unknown"))
    }

    func testRuntimeSummaryDecodes() throws {
        let data = Data("""
        {
          "profile": {
            "id": "local-default",
            "name": "Local iii",
            "kind": "local",
            "host": "127.0.0.1",
            "httpPort": 3111,
            "bridgePort": 49134,
            "streamPort": 3112
          },
          "reachable": true,
          "status": "healthy",
          "workerCount": 2,
          "externalWorkerCount": 1,
          "internalWorkerCount": 1,
          "processCount": 2,
          "functionCount": 192,
          "triggerCount": 12,
          "activeInvocations": 0,
          "longestUptimeSeconds": 120,
          "endpoints": [
            { "label": "engine ws", "url": "ws://127.0.0.1:49134", "available": true }
          ],
          "workers": [
            {
              "id": "one",
              "name": "worker-one",
              "status": "running",
              "runtime": "node",
              "pid": 123,
              "ipAddress": "127.0.0.1",
              "internal": false,
              "functionCount": 8,
              "activeInvocations": 0,
              "memoryRssBytes": 67108864,
              "cpuPercent": 12.5
            }
          ],
          "runtimes": { "node": 1 },
          "locations": { "127.0.0.1": 2 },
          "resources": {
            "metricsAvailable": true,
            "workersWithMetrics": 1,
            "cpuPercent": 12.5,
            "memoryRssBytes": 67108864
          },
          "checkedAt": "2026-05-11T00:00:00.000Z"
        }
        """.utf8)

        let result = try JSONDecoder().decode(RuntimeSummary.self, from: data)
        XCTAssertEqual(result.workerCount, 2)
        XCTAssertEqual(result.processCount, 2)
        XCTAssertEqual(result.resources.cpuPercent, 12.5)
        XCTAssertEqual(result.workers.first?.pid, 123)
    }
}
