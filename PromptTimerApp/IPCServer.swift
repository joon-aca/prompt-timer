import Darwin
import Foundation
import PromptTimerCore

final class IPCServer {
    private let logger = PromptTimerLogger(category: "IPCServer")
    private let host: String
    private let port: UInt16
    private let handler: @Sendable (IPCCommand) async -> IPCResponse
    private let queue = DispatchQueue(label: "PromptTimer.IPCServer")

    private var listeningFileDescriptor: Int32 = -1
    private var acceptSource: DispatchSourceRead?

    init(
        host: String,
        port: UInt16,
        handler: @escaping @Sendable (IPCCommand) async -> IPCResponse
    ) {
        self.host = host
        self.port = port
        self.handler = handler
    }

    func start() throws {
        stop()
        logger.debug("Starting IPC server on \(host):\(port)")

        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw IPCServerError.socket(Self.lastError("Failed to create socket"))
        }

        listeningFileDescriptor = descriptor
        _ = fcntl(descriptor, F_SETFL, O_NONBLOCK)

        var reuseAddress: Int32 = 1
        setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuseAddress,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var address = try SocketAddress(host: host, port: port)
        let bindResult = withUnsafePointer(to: &address.storage) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, address.length)
            }
        }

        guard bindResult == 0 else {
            stop()
            throw IPCServerError.socket(Self.lastError("Failed to bind socket"))
        }

        guard listen(descriptor, 8) == 0 else {
            stop()
            throw IPCServerError.socket(Self.lastError("Failed to listen on socket"))
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
                logger.error(Self.lastError("Failed accepting client"))
                return
            }

            logger.debug("Accepted client connection")
            Self.makeBlocking(clientDescriptor)
            handleClient(clientDescriptor)
        }
    }

    private func handleClient(_ clientDescriptor: Int32) {
        queue.async { [handler, logger] in
            do {
                let requestData = try Self.readAll(from: clientDescriptor)
                let command = try IPCCodec.decoder.decode(IPCCommand.self, from: requestData)
                logger.debug("Received command \(command.command.rawValue)")

                Task {
                    let response = await handler(command)
                    do {
                        let data = try IPCCodec.encoder.encode(response)
                        try Self.writeAll(data, to: clientDescriptor)
                        logger.debug("Sent response ok=\(response.ok)")
                    } catch {
                        logger.error("Failed writing response: \(error.localizedDescription)")
                        let fallback = IPCResponse.failure(error.localizedDescription)
                        let data = (try? IPCCodec.encoder.encode(fallback)) ?? Data()
                        try? Self.writeAll(data, to: clientDescriptor)
                    }

                    shutdown(clientDescriptor, SHUT_WR)
                    close(clientDescriptor)
                }
            } catch {
                logger.error("Failed handling client: \(error.localizedDescription)")
                let fallback = IPCResponse.failure(error.localizedDescription)
                let data = (try? IPCCodec.encoder.encode(fallback)) ?? Data()
                try? Self.writeAll(data, to: clientDescriptor)
                shutdown(clientDescriptor, SHUT_WR)
                close(clientDescriptor)
            }
        }
    }

    private static func readAll(from descriptor: Int32) throws -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        while true {
            let bytesRead = read(descriptor, &buffer, buffer.count)
            if bytesRead > 0 {
                data.append(contentsOf: buffer.prefix(bytesRead))
                continue
            }
            if bytesRead == 0 {
                break
            }
            if errno == EINTR {
                continue
            }
            if errno == EAGAIN || errno == EWOULDBLOCK {
                if !data.isEmpty {
                    break
                }
                usleep(1_000)
                continue
            }
            throw IPCServerError.socket(lastError("Failed while reading request"))
        }

        return data
    }

    private static func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }

            var bytesWritten = 0
            while bytesWritten < data.count {
                let result = write(descriptor, baseAddress.advanced(by: bytesWritten), data.count - bytesWritten)
                if result < 0 {
                    if errno == EINTR {
                        continue
                    }
                    if errno == EAGAIN || errno == EWOULDBLOCK {
                        usleep(1_000)
                        continue
                    }
                    throw IPCServerError.socket(lastError("Failed while writing response"))
                }
                bytesWritten += result
            }
        }
    }

    private static func makeBlocking(_ descriptor: Int32) {
        let flags = fcntl(descriptor, F_GETFL)
        guard flags >= 0 else {
            return
        }
        _ = fcntl(descriptor, F_SETFL, flags & ~O_NONBLOCK)
    }

    private static func lastError(_ prefix: String) -> String {
        "\(prefix): \(String(cString: strerror(errno)))"
    }
}

private enum IPCServerError: LocalizedError {
    case socket(String)

    var errorDescription: String? {
        switch self {
        case let .socket(message):
            return message
        }
    }
}

private struct SocketAddress {
    var storage = sockaddr_in()
    let length: socklen_t

    init(host: String, port: UInt16) throws {
        let hostAddress = host.withCString { inet_addr($0) }
        guard hostAddress != INADDR_NONE else {
            throw IPCServerError.socket("Invalid IPC host.")
        }

        storage.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        storage.sin_family = sa_family_t(AF_INET)
        storage.sin_port = port.bigEndian
        storage.sin_addr = in_addr(s_addr: hostAddress)
        storage.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        length = socklen_t(MemoryLayout<sockaddr_in>.size)
    }
}
