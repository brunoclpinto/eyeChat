//
//  IPCMessage.swift
//  eyeChat Shared
//
//  Shared codable message definitions for the IPC transport.
//

import Foundation

enum IPCSender: String, Codable {
    case cli
    case gui
    case daemon
}

enum IPCCommand: String, Codable {
    case say
    case help
    case quit
    case list
    case custom
}

enum IPCStatus: String, Codable {
    case ok
    case error
}

/// Generic JSON-like payload that supports strings, numbers, booleans, null, arrays, and nested dictionaries.
enum IPCPayloadValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([IPCPayloadValue])
    case object([String: IPCPayloadValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([IPCPayloadValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: IPCPayloadValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.typeMismatch(IPCPayloadValue.self, DecodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported IPC payload type"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let string):
            try container.encode(string)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .bool(let bool):
            try container.encode(bool)
        case .array(let array):
            try container.encode(array)
        case .object(let object):
            try container.encode(object)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let string) = self {
            return string
        }
        return nil
    }
}

typealias IPCPayload = [String: IPCPayloadValue]

struct IPCMessage: Codable {
    var id: UUID
    var sender: IPCSender
    var command: IPCCommand
    var params: IPCPayload
    var timestamp: TimeInterval
    var response: IPCPayload?
    var status: IPCStatus?
    var protocolVersion: String

    init(
        id: UUID = UUID(),
        sender: IPCSender,
        command: IPCCommand,
        params: IPCPayload = [:],
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        response: IPCPayload? = nil,
        status: IPCStatus? = nil,
        protocolVersion: String = IPCConstants.protocolVersion
    ) {
        self.id = id
        self.sender = sender
        self.command = command
        self.params = params
        self.timestamp = timestamp
        self.response = response
        self.status = status
        self.protocolVersion = protocolVersion
    }

    func withResponse(_ response: IPCPayload, status: IPCStatus = .ok, sender overrideSender: IPCSender? = nil) -> IPCMessage {
        IPCMessage(
            id: id,
            sender: overrideSender ?? sender,
            command: command,
            params: params,
            timestamp: timestamp,
            response: response,
            status: status,
            protocolVersion: protocolVersion
        )
    }

    func withError(_ message: String) -> IPCMessage {
        let payload: IPCPayload = ["error": .string(message)]
        return withResponse(payload, status: .error)
    }
}

extension IPCMessage {
    var shouldCloseConnection: Bool {
        response?["action"]?.stringValue == "close"
    }
}
