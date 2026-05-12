import Foundation

actor IiiFunctionClient {
    enum ClientError: Error {
        case disconnected
        case invalidResponse
        case engineError(String)
        case timeout(String)
    }

    private let url: URL
    private var task: URLSessionWebSocketTask?
    private var pending: [String: CheckedContinuation<Data, Error>] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(url: URL) {
        self.url = url
    }

    func connect() {
        guard task == nil else { return }
        let nextTask = URLSession.shared.webSocketTask(with: url)
        task = nextTask
        nextTask.resume()
        receive()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        pending.values.forEach { $0.resume(throwing: ClientError.disconnected) }
        pending.removeAll()
    }

    func invoke<T: Decodable>(_ functionId: String, payload: EncodablePayload = EncodablePayload.empty) async throws -> T {
        connect()
        guard let task else { throw ClientError.disconnected }
        let invocationId = UUID().uuidString.lowercased()
        let envelope = InvokeEnvelope(
            type: "invokefunction",
            invocationId: invocationId,
            functionId: functionId,
            data: payload.value
        )
        let messageData = try encoder.encode(envelope)
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            self.failInvocation(invocationId, error: ClientError.timeout(functionId))
        }
        let result = try await withCheckedThrowingContinuation { continuation in
            pending[invocationId] = continuation
            task.send(.data(messageData)) { error in
                if let error {
                    Task {
                        await self.failConnection(error)
                    }
                }
            }
        }
        timeoutTask.cancel()
        return try decoder.decode(T.self, from: result)
    }

    private func failInvocation(_ invocationId: String, error: Error) {
        pending.removeValue(forKey: invocationId)?.resume(throwing: error)
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            Task {
                await self.handle(result)
                await self.receive()
            }
        }
    }

    private func handle(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case .failure(let error):
            failConnection(error)
        case .success(let message):
            guard let data = message.dataValue else { return }
            guard let response = try? decoder.decode(InvocationEnvelope.self, from: data) else { return }
            guard let continuation = pending.removeValue(forKey: response.invocationId) else { return }
            if let error = response.error {
                continuation.resume(throwing: ClientError.engineError(error.message))
            } else if let result = response.result {
                continuation.resume(returning: result)
            } else {
                continuation.resume(throwing: ClientError.invalidResponse)
            }
        }
    }

    private func failConnection(_ error: Error) {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        let continuations = pending.values
        pending.removeAll()
        continuations.forEach { $0.resume(throwing: error) }
    }
}

extension IiiFunctionClient.ClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .disconnected:
            return "iii control engine is disconnected"
        case .invalidResponse:
            return "iiiBar received an invalid function response"
        case .engineError(let message):
            return message
        case .timeout(let functionId):
            return "Timed out waiting for \(functionId)"
        }
    }
}

struct EncodablePayload: Encodable {
    let value: AnyEncodable

    static let empty = EncodablePayload([String: String]())

    init<T: Encodable>(_ value: T) {
        self.value = AnyEncodable(value)
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

struct InvokeEnvelope: Encodable {
    var type: String
    var invocationId: String
    var functionId: String
    var data: AnyEncodable

    enum CodingKeys: String, CodingKey {
        case type
        case invocationId = "invocation_id"
        case functionId = "function_id"
        case data
    }
}

struct InvocationEnvelope: Decodable {
    var invocationId: String
    var result: Data?
    var error: EngineError?

    enum CodingKeys: String, CodingKey {
        case invocationId = "invocation_id"
        case result
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        invocationId = try container.decode(String.self, forKey: .invocationId)
        error = try container.decodeIfPresent(EngineError.self, forKey: .error)
        if container.contains(.result) {
            let value = try container.decode(JSONValue.self, forKey: .result)
            result = try JSONEncoder().encode(value)
        }
    }
}

struct EngineError: Decodable {
    var code: String?
    var message: String
}

extension URLSessionWebSocketTask.Message {
    var dataValue: Data? {
        switch self {
        case .data(let data):
            return data
        case .string(let string):
            return Data(string.utf8)
        @unknown default:
            return nil
        }
    }
}
