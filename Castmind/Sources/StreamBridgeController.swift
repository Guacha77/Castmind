import Foundation
import Network

final class StreamBridgeController {
    private var listener: NWListener?
    private var latestText = ""
    private let queue = DispatchQueue(label: "castmind.stream.bridge")

    func start(port: UInt16, initialText: String) {
        latestText = initialText
        stop()

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port) ?? 17382)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            listener = nil
        }
    }

    func publish(_ text: String) {
        queue.async { [weak self] in
            self?.latestText = text
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        let response = """
        HTTP/1.1 200 OK
        Content-Type: text/plain; charset=utf-8
        Cache-Control: no-store
        Connection: close

        \(latestText)
        """
        let data = Data(response.utf8)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
