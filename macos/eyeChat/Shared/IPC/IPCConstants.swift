//
//  IPCConstants.swift
//  eyeChat Shared
//
//  Defines constants that coordinate the IPC layer across the daemon and clients.
//

import Foundation

enum IPCConstants {
    static let socketPath = "/tmp/eyechat.sock"
    static let logPath = "/tmp/eyechat.log"
    static let protocolVersion = "0.1"

    /// Frames are delimited by a newline character to simplify streaming parsing.
    static let frameTerminator = "\n".data(using: .utf8)!
}
