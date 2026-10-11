import Foundation

nonisolated struct DeviceCommand: Encodable, Sendable {
    var component = "main"
    let capability: String
    let command: String
    var arguments: [JSONValue] = []
}

enum SmartThingsError: LocalizedError {
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .http(let status, let body): String(localized: "SmartThings responded \(status): \(String(body.prefix(160)))")
        }
    }
}

final class SmartThingsClient {
    private let auth: AuthManager
    private let baseURL = URL(string: "https://api.smartthings.com/v1")!

    init(auth: AuthManager) {
        self.auth = auth
    }

    func airConditioners() async throws -> [ACDevice] {
        let data = try await request("devices?capability=airConditionerMode")
        let list = try JSONDecoder().decode(DeviceList.self, from: data)
        return list.items
            .map { ACDevice(id: $0.deviceId, label: $0.label ?? $0.name ?? String(localized: "Air conditioner")) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    func state(of deviceID: String) async throws -> ACState {
        let data = try await request("devices/\(deviceID)/components/main/status")
        let status = try JSONDecoder().decode([String: JSONValue].self, from: data)
        return ACState(status: status)
    }

    func send(_ commands: [DeviceCommand], to deviceID: String) async throws {
        let body = try JSONEncoder().encode(["commands": commands])
        _ = try await request("devices/\(deviceID)/commands", method: "POST", body: body)
    }

    // Without this, the cloud keeps old values (for example `fanMode`) after a command.
    func requestReport(from deviceID: String) async throws {
        try await send([DeviceCommand(capability: "refresh", command: "refresh")], to: deviceID)
    }

    private func request(_ path: String, method: String = "GET", body: Data? = nil, isRetry: Bool = false) async throws -> Data {
        var request = URLRequest(url: URL(string: path, relativeTo: baseURL)!)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await auth.accessToken(forceRefresh: isRetry))", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401, !isRetry {
            return try await self.request(path, method: method, body: body, isRetry: true)
        }
        guard (200..<300).contains(status) else {
            throw SmartThingsError.http(status, String(decoding: data, as: UTF8.self))
        }
        return data
    }
}

private nonisolated struct DeviceList: Decodable {
    struct Item: Decodable {
        let deviceId: String
        let label: String?
        let name: String?
    }
    let items: [Item]
}
