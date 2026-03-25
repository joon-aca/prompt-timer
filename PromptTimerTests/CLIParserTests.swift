import Testing
@testable import TimerCLI

@Test func parsesStartCommand() throws {
    let parsed = try CLIParser.parse(arguments: ["25", "deep", "work"])
    guard case let .ipc(command) = parsed else {
        Issue.record("Expected IPC command")
        return
    }

    #expect(command.command == .start)
    #expect(command.durationSeconds == 1500)
    #expect(command.label == "deep work")
}

@Test func parsesListStatusAndHelp() throws {
    #expect(try CLIParser.parse(arguments: ["list"]) == .ipc(.list()))
    #expect(try CLIParser.parse(arguments: ["ls"]) == .ipc(.list()))
    #expect(try CLIParser.parse(arguments: ["status"]) == .ipc(.status()))
    #expect(try CLIParser.parse(arguments: ["help"]) == .help)
}

@Test func parsesCancelCommands() throws {
    #expect(try CLIParser.parse(arguments: ["cancel"]) == .ipc(.cancel()))
    #expect(try CLIParser.parse(arguments: ["cancel", "all"]) == .ipc(.cancelAll()))
    #expect(try CLIParser.parse(arguments: ["cancel", "abc123"]) == .ipc(.cancel(id: "abc123")))
}
