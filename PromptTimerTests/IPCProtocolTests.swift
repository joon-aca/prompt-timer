import Foundation
import Testing
@testable import PromptTimerCore

@Test func encodesAndDecodesIPCCommand() throws {
    let command = IPCCommand.start(
        durationSeconds: 1500,
        label: "deep work",
        action: .launchApplication(target: "us.zoom.xos", displayName: "Zoom")
    )
    let data = try IPCCodec.encoder.encode(command)
    let decoded = try IPCCodec.decoder.decode(IPCCommand.self, from: data)
    #expect(decoded == command)
}

@Test func encodesAndDecodesIPCResponse() throws {
    let response = IPCResponse.success(
        "Started timer",
        timers: [
            IPCTimerSnapshot(
                id: "abc123",
                label: "deep work",
                action: .launchApplication(target: "us.zoom.xos", displayName: "Zoom"),
                durationSeconds: 1500,
                remainingSeconds: 1499,
                dueAt: Date(timeIntervalSince1970: 100),
                state: .active
            ),
        ]
    )

    let data = try IPCCodec.encoder.encode(response)
    let decoded = try IPCCodec.decoder.decode(IPCResponse.self, from: data)
    #expect(decoded == response)
}
