import Darwin
import Foundation

public enum IPCSocketError: LocalizedError {
    case socket(String)

    public var errorDescription: String? {
        switch self {
        case let .socket(message):
            return message
        }
    }
}

public struct UnixSocketAddress {
    public var storage = sockaddr_un()
    public let length: socklen_t

    public init(path: String) throws {
        let pathBytes = path.utf8CString
        let maxLen = MemoryLayout.size(ofValue: storage.sun_path)
        guard pathBytes.count <= maxLen else {
            throw IPCSocketError.socket("Socket path exceeds \(maxLen - 1) characters")
        }
        storage.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        storage.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &storage.sun_path) { sunPath in
            sunPath.withMemoryRebound(to: CChar.self, capacity: maxLen) { dest in
                for (i, byte) in pathBytes.enumerated() {
                    dest[i] = byte
                }
            }
        }
        length = socklen_t(MemoryLayout<sockaddr_un>.size)
    }
}

public enum IPCSocket {
    public static func readAll(from descriptor: Int32) throws -> Data {
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
            throw IPCSocketError.socket(lastError("Read failed"))
        }

        return data
    }

    public static func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }

            var bytesWritten = 0
            while bytesWritten < data.count {
                let result = write(
                    descriptor, baseAddress.advanced(by: bytesWritten), data.count - bytesWritten
                )
                if result < 0 {
                    if errno == EINTR {
                        continue
                    }
                    if errno == EAGAIN || errno == EWOULDBLOCK {
                        usleep(1_000)
                        continue
                    }
                    throw IPCSocketError.socket(lastError("Write failed"))
                }
                bytesWritten += result
            }
        }
    }

    public static func connect(to path: String) throws -> Int32 {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw IPCSocketError.socket(lastError("Failed to create socket"))
        }

        var address = try UnixSocketAddress(path: path)
        let result = withUnsafePointer(to: &address.storage) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, address.length)
            }
        }

        guard result == 0 else {
            close(descriptor)
            throw IPCSocketError.socket(lastError("Failed to connect to Prompt Timer"))
        }

        return descriptor
    }

    public static func makeBlocking(_ descriptor: Int32) {
        let flags = fcntl(descriptor, F_GETFL)
        guard flags >= 0 else { return }
        _ = fcntl(descriptor, F_SETFL, flags & ~O_NONBLOCK)
    }

    public static func lastError(_ prefix: String) -> String {
        "\(prefix): \(String(cString: strerror(errno)))"
    }
}
