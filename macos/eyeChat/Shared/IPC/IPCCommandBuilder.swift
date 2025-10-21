//
//  IPCCommandBuilder.swift
//  eyeChat Shared
//
//  Parses raw user input into structured IPC messages.
//

import Foundation

enum IPCCommandBuilder {
    static func buildMessage(from input: String, sender: IPCSender) -> IPCMessage? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowercased = trimmed.lowercased()

        if lowercased == "help" {
            return IPCMessage(sender: sender, command: .help)
        }

        if lowercased == "list" {
            return IPCMessage(sender: sender, command: .list)
        }

        if lowercased == "quit" || lowercased == "exit" {
            return IPCMessage(sender: sender, command: .quit)
        }

        let sayPrefix = "say "
        if lowercased.hasPrefix(sayPrefix), trimmed.count > sayPrefix.count {
            let text = String(trimmed.dropFirst(sayPrefix.count)).trimmingCharacters(in: .whitespaces)
            return IPCMessage(sender: sender, command: .say, params: ["text": .string(text)])
        }

        return IPCMessage(sender: sender, command: .say, params: ["text": .string(trimmed)])
    }
}
