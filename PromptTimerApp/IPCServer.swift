import Darwin
import Foundation
import PromptTimerCore

final class IPCServer {
    private let logger = PromptTimerLogger(category: "IPCServer")
    private let socketPath: String
    private let handler: @Sendable (IPCCommand) async -> IPCResponse
    private let queue = DispatchQueue(label: "PromptTimer.IPCServer")

    private var listeningFileDescriptor: Int32 = -1
    private var acceptSource: DispatchSourceRead?

    init(
        socketPath: String,
        handler: @escaping @Sendable (IPCCommand) async -> IPCResponse
    ) {
        self.socketPath = socketPath
        self.handler = handler
    }

    func start() throws {
        stop()
        logger.debug("Starting IPC server on \(socketPath)")
        unlink(socketPath)

        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw IPCSocketError.socket(IPCSocket.lastError("Failed to create socket"))
        }

        listeningFileDescriptor = descriptor
        _ = fcntl(descriptor, F_SETFL, O_NONBLOCK)

        var address = try UnixSocketAddress(path: socketPath)
        let bindResult = withUnsafePointer(to: &address.storage) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, address.length)
            }
        }

        guard bindResult == 0 else {
            stop()
            throw IPCSocketError.socket(IPCSocket.lastError("Failed to bind socket"))
        }

        guard listen(descriptor, 8) == 0 else {
            stop()
            throw IPCSocketError.socket(IPCSocket.lastError("Failed to listen on socket"))
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptConnections()
        }
        source.setCancelHandler { [descriptor] in
            close(descriptor)
        }
        acceptSource = source
        source.resume()
    }

    func stop() {
        if let acceptSource {
            acceptSource.cancel()
            self.acceptSource = nil
            listeningFileDescriptor = -1
        } else if listeningFileDescriptor >= 0 {
            close(listeningFileDescriptor)
            listeningFileDescriptor = -1
        }
        unlink(socketPath)
    }

    deinit {
        stop()
    }

    private func acceptConnections() {
        while true {
            let clientDescriptor = accept(listeningFileDescriptor, nil, nil)

            if clientDescriptor < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    return
                }
                logger.error(IPCSocket.lastError("Failed accepting client"))
                return
            }

            logger.debug("Accepted client connection")
            IPCSocket.makeBlocking(clientDescriptor)
            handleClient(clientDescriptor)
        }
    }

    private func handleClient(_ clientDescriptor: Int32) {
        queue.async { [handler, logger] in
            do {
                let requestData = try IPCSocket.readAll(from: clientDescriptor)
                let command = try IPCCodec.decoder.decode(IPCCommand.self, from: requestData)
                logger.debug("Received command \(command.command.rawValue)")

                Task {
                    let response = await handler(command)
                    do {
                        let data = try IPCCodec.encoder.encode(response)
                        try IPCSocket.writeAll(data, to: clientDescriptor)
                        logger.debug("Sent response ok=\(response.ok)")
                    } catch {
                        logger.error("Failed writing response: \(error.localizedDescription)")
                        let fallback = IPCResponse.failure(error.localizedDescription)
                        let data = (try? IPCCodec.encoder.encode(fallback)) ?? Data()
                        try? IPCSocket.writeAll(data, to: clientDescriptor)
                    }

                    shutdown(clientDescriptor, SHUT_WR)
                    close(clientDescriptor)
                }
            } catch {
                logger.error("Failed handling client: \(error.localizedDescription)")
                let fallback = IPCResponse.failure(error.localizedDescription)
                let data = (try? IPCCodec.encoder.encode(fallback)) ?? Data()
                try? IPCSocket.writeAll(data, to: clientDescriptor)
                shutdown(clientDescriptor, SHUT_WR)
                close(clientDescriptor)
            }
        }
    }
}
