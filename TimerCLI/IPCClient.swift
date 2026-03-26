import Darwin
import Foundation
import PromptTimerCore

public struct IPCClient {
    public let socketPath: String

    public init(socketPath: String) {
        self.socketPath = socketPath
    }

    public func send(_ command: IPCCommand) throws -> IPCResponse {
        VerboseLogger.log("Connecting to \(socketPath)")
        let descriptor = try IPCSocket.connect(to: socketPath)
        defer { close(descriptor) }

        let payload = try IPCCodec.encoder.encode(command)
        VerboseLogger.log("Sending \(payload.count) bytes for command \(command.command.rawValue)")
        try IPCSocket.writeAll(payload, to: descriptor)
        shutdown(descriptor, SHUT_WR)

        let responseData = try IPCSocket.readAll(from: descriptor)
        VerboseLogger.log("Received \(responseData.count) bytes in response")
        return try IPCCodec.decoder.decode(IPCResponse.self, from: responseData)
    }
}
