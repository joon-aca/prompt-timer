import Darwin
import Foundation
import PromptTimerCore
import TimerCLI

let rawArguments = Array(CommandLine.arguments.dropFirst())
var useAlfredOutput = false
var useVerboseOutput = false
var arguments: [String] = []

for argument in rawArguments {
    switch argument {
    case "--alfred":
        useAlfredOutput = true
    case "--verbose":
        useVerboseOutput = true
    default:
        arguments.append(argument)
    }
}

VerboseLogger.setEnabled(useVerboseOutput)
VerboseLogger.log("Arguments: \(arguments)")

do {
    let parsed = try CLIParser.parse(arguments: arguments)
    switch parsed {
    case .help:
        print(OutputFormatter.helpText)
        exit(EXIT_SUCCESS)

    case let .ipc(command):
        VerboseLogger.log("Parsed command: \(command.command.rawValue)")
        let store = try TimerStore()
        let client = IPCClient(
            host: store.ipcHost,
            port: store.ipcPort
        )
        let response = try send(command: command, with: client)
        let output = OutputFormatter.render(response, mode: useAlfredOutput ? .alfred : .terminal)
        print(output)
        exit(response.ok ? EXIT_SUCCESS : EXIT_FAILURE)
    }
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
}

private func send(command: IPCCommand, with client: IPCClient) throws -> IPCResponse {
    do {
        VerboseLogger.log("Sending initial request")
        return try client.send(command)
    } catch {
        VerboseLogger.log("Initial request failed: \(error.localizedDescription)")
        AgentLauncher.launchIfNeeded()

        for attempt in 1...20 {
            usleep(150_000)
            if let response = try? client.send(command) {
                VerboseLogger.log("Retry \(attempt) succeeded")
                return response
            }
            VerboseLogger.log("Retry \(attempt) failed")
        }

        throw error
    }
}
