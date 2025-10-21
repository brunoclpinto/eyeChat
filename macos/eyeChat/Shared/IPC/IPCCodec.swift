//
//  IPCCodec.swift
//  eyeChat Shared
//
//  Encodes and decodes IPC messages to newline-delimited JSON frames.
//

import Foundation

enum IPCCodec {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    static func encode(_ message: IPCMessage) throws -> Data {
        let payload = try encoder.encode(message)
        guard var framed = String(data: payload, encoding: .utf8)?.data(using: .utf8) else {
            throw IPCError.invalidMessage
        }
        framed.append(IPCConstants.frameTerminator)
        return framed
    }

    static func decodeMessages(from buffer: inout Data) throws -> [IPCMessage] {
        var messages: [IPCMessage] = []

        while let range = buffer.range(of: IPCConstants.frameTerminator) {
            let frame = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)

            guard !frame.isEmpty else { continue }

            do {
                let message = try decoder.decode(IPCMessage.self, from: frame)
                messages.append(message)
            } catch {
                IPCLogger.log("Decode error: \(error.localizedDescription)", category: "codec")
                throw IPCError.invalidMessage
            }
        }

        return messages
    }
}
