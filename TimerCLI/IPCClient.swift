import Darwin
import Foundation
import PromptTimerCore

public struct IPCClient {
    public let host: String
    public let port: UInt16

    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    public func send(_ command: IPCCommand) throws -> IPCResponse {
        VerboseLogger.log("Connecting to \(host):\(port)")
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw IPCClientError.socket(Self.lastError("Failed to create client socket"))
        }

        defer {
            close(descriptor)
        }

        var address = try SocketAddress(host: host, port: port)
        let connectResult = withUnsafePointer(to: &address.storage) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, address.length)
            }
        }

        guard connectResult == 0 else {
            throw IPCClientError.socket(Self.lastError("Failed to connect to Prompt Timer"))
        }

        let payload = try IPCCodec.encoder.encode(command)
        VerboseLogger.log("Sending \(payload.count) bytes for command \(command.command.rawValue)")
        try Self.writeAll(payload, to: descriptor)
        shutdown(descriptor, SHUT_WR)

        let responseData = try Self.readAll(from: descriptor)
        VerboseLogger.log("Received \(responseData.count) bytes in response")
        return try IPCCodec.decoder.decode(IPCResponse.self, from: responseData)
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
            throw IPCClientError.socket(lastError("Failed while reading response"))
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
                    throw IPCClientError.socket(lastError("Failed while writing request"))
                }
                bytesWritten += result
            }
        }
    }

    private static func lastError(_ prefix: String) -> String {
        "\(prefix): \(String(cString: strerror(errno)))"
    }
}

private enum IPCClientError: LocalizedError {
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
            throw IPCClientError.socket("Invalid host.")
        }
        storage.sin_family = sa_family_t(AF_INET)
        storage.sin_port = port.bigEndian
        storage.sin_addr = in_addr(s_addr: hostAddress)
        storage.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        length = socklen_t(MemoryLayout<sockaddr_in>.size)
    }
}
