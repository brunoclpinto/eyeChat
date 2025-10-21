//
//  IPCError.swift
//  eyeChat Shared
//
//  Enumerates error cases shared across the IPC layer.
//

import Foundation

enum IPCError: Error {
    case socketCreationFailed(errno: Int32)
    case socketBindFailed(errno: Int32)
    case socketListenFailed(errno: Int32)
    case socketAcceptFailed(errno: Int32)
    case socketConnectFailed(errno: Int32)
    case socketSendFailed(errno: Int32)
    case socketReceiveFailed(errno: Int32)
    case invalidMessage
    case unauthorizedPeer
    case connectionClosed
    case notConnected
    case alreadyStarted
}
