//
//  IPCCommandRouter.swift
//  eyeChat Shared
//
//  Provides a simple, extendable command router for daemon requests.
//

import Foundation

protocol IPCCommandRouter {
    func handle(message: IPCMessage) -> IPCMessage
}

struct DefaultIPCCommandRouter: IPCCommandRouter {
    func handle(message: IPCMessage) -> IPCMessage {
        switch message.command {
        case .say:
            return handleSay(message)
        case .help:
            return handleHelp(message)
        case .quit:
            return handleQuit(message)
        case .list:
            return handleList(message)
        case .custom:
            return handleCustom(message)
        }
    }

    private func handleSay(_ message: IPCMessage) -> IPCMessage {
        let text = message.params["text"]?.stringValue ?? ""
        guard !text.isEmpty else {
            return message.withError("Missing 'text' parameter for say command.")
        }

        SpeechOutputManager.shared.speak(text)
        return message.withResponse(["text": .string(text), "status": .string("spoken")], sender: .daemon)
    }

    private func handleHelp(_ message: IPCMessage) -> IPCMessage {
        let commands = [
            "say <text> — speaks the provided text.",
            "help — displays this help.",
            "quit — closes the connection.",
            "list — enumerates available commands."
        ]
        return message.withResponse(["text": .string(commands.joined(separator: "\n")), "commands": .array(commands.map { .string($0) })], sender: .daemon)
    }

    private func handleQuit(_ message: IPCMessage) -> IPCMessage {
        return message.withResponse(["text": .string("Goodbye."), "action": .string("close")], sender: .daemon)
    }

    private func handleList(_ message: IPCMessage) -> IPCMessage {
        let commandNames: [IPCPayloadValue] = IPCCommand.allCases.map { .string($0.rawValue) }
        return message.withResponse(["commands": .array(commandNames)], sender: .daemon)
    }

    private func handleCustom(_ message: IPCMessage) -> IPCMessage {
        return message.withError("Custom command routing is not yet implemented.")
    }
}

private extension IPCCommand {
    static var allCases: [IPCCommand] {
        [.say, .help, .quit, .list, .custom]
    }
}
