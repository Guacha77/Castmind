import Foundation

struct DiscoveredBridge: Identifiable, Equatable {
    var id: String { "\(host):\(port)" }
    var name: String
    var host: String
    var port: Int
}

@MainActor
final class BridgeDiscoveryService: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published private(set) var services: [DiscoveredBridge] = []
    @Published private(set) var isSearching = false

    private let browser = NetServiceBrowser()
    private var resolving: [NetService] = []

    override init() {
        super.init()
        browser.delegate = self
    }

    func start() {
        guard !isSearching else { return }
        services = []
        resolving = []
        isSearching = true
        browser.searchForServices(ofType: "_castmind._tcp.", inDomain: "local.")
    }

    func stop() {
        browser.stop()
        isSearching = false
        resolving.removeAll()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        resolving.append(service)
        service.resolve(withTimeout: 4)
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        isSearching = false
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let raw = sender.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")), sender.port > 0 else { return }
        let item = DiscoveredBridge(name: sender.name, host: raw, port: sender.port)
        if !services.contains(where: { $0.id == item.id }) { services.append(item) }
    }
}

@MainActor
final class StreamBridgeService: ObservableObject {
    enum Status: Equatable {
        case disconnected
        case connecting
        case connected(String)
        case failed(String)
    }

    @Published private(set) var status: Status = .disconnected

    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var endpoint: String?

    var statusText: String {
        switch status {
        case .disconnected: return "Desconectado"
        case .connecting: return "Conectando"
        case .connected(let target): return "Conectado · \(target)"
        case .failed: return "Error"
        }
    }

    func connect(host: String, port: Int) async {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty, (1...65535).contains(port) else {
            status = .failed("Dirección o puerto no válidos")
            return
        }
        let safeHost = cleanHost.contains(":") ? "[\(cleanHost)]" : cleanHost
        let newEndpoint = "ws://\(safeHost):\(port)"
        if endpoint == newEndpoint, case .connected = status { return }

        disconnect()
        guard let url = URL(string: newEndpoint) else {
            status = .failed("URL local no válida")
            return
        }

        status = .connecting
        endpoint = newEndpoint
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: configuration)
        let task = session.webSocketTask(with: url)
        self.session = session
        self.task = task
        task.resume()

        let ok = await ping(task)
        status = ok ? .connected("\(cleanHost):\(port)") : .failed("No se pudo contactar con el companion")
        if !ok { disconnect(keepFailure: true) }
    }

    func disconnect(keepFailure: Bool = false) {
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        task = nil
        session = nil
        endpoint = nil
        if !keepFailure { status = .disconnected }
    }

    func test(settings: BridgeSettings) async throws {
        await connect(host: settings.host, port: settings.port)
        guard case .connected = status else { throw BridgeError.notConnected }
        try await send(BridgeEvent.test(secret: settings.secret))
    }

    func sendReply(text: String, character: CharacterProfile, settings: BridgeSettings, cue: String = "normal") async throws {
        if case .connected = status {
            // Reuse current connection.
        } else {
            await connect(host: settings.host, port: settings.port)
        }
        guard case .connected = status else { throw BridgeError.notConnected }
        let e = character.emotion
        try await send(
            BridgeEvent(
                type: "assistant_reply",
                secret: settings.secret,
                characterID: character.id.uuidString,
                character: character.name,
                text: text,
                cue: cue,
                accentHex: character.accentHex,
                anger: e.anger,
                trust: e.trust,
                energy: e.energy,
                mood: e.mood,
                excitement: e.excitement,
                sentAt: Date()
            )
        )
    }

    private func send(_ event: BridgeEvent) async throws {
        guard let task else { throw BridgeError.notConnected }
        let data = try JSONEncoder().encode(event)
        guard let string = String(data: data, encoding: .utf8) else { throw BridgeError.encoding }
        try await task.send(.string(string))
    }

    private func ping(_ task: URLSessionWebSocketTask) async -> Bool {
        await withCheckedContinuation { continuation in
            task.sendPing { error in continuation.resume(returning: error == nil) }
        }
    }

    private struct BridgeEvent: Codable {
        let type: String
        let secret: String
        let characterID: String
        let character: String
        let text: String
        let cue: String
        let accentHex: String
        let anger: Double
        let trust: Double
        let energy: Double
        let mood: Double
        let excitement: Double
        let sentAt: Date

        static func test(secret: String) -> BridgeEvent {
            BridgeEvent(type: "test", secret: secret, characterID: "castmind", character: "Castmind", text: "Conexión V2 correcta", cue: "test", accentHex: "9C6BFF", anger: 0, trust: 0, energy: 0, mood: 0, excitement: 0, sentAt: Date())
        }
    }

    enum BridgeError: LocalizedError {
        case notConnected, encoding
        var errorDescription: String? {
            switch self {
            case .notConnected: return "No hay conexión con Stream Bridge."
            case .encoding: return "No se pudo preparar el mensaje para el PC."
            }
        }
    }
}
