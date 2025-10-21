//
//  IPCClient.swift
//  eyeChat Shared
//
//  Unix domain socket client for daemon communication.
//

import Foundation
import Darwin

final class IPCClient {
    private let queue = DispatchQueue(label: "io.eyeChat.ipc.client")
    private let callbackQueue: DispatchQueue

    private var socketFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var buffer = Data()
    private var connected = false

    var onMessage: ((IPCMessage) -> Void)?
    var onConnect: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onDisconnect: (() -> Void)?

    init(callbackQueue: DispatchQueue = .main) {
        self.callbackQueue = callbackQueue
    }

    deinit {
        close()
    }

    func connect() {
        queue.async {
            guard !self.connected else { return }

            self.socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
            guard self.socketFD != -1 else {
                self.emitError(IPCError.socketCreationFailed(errno: errno))
                return
            }

            do {
                try self.configureSocket(self.socketFD)
                try self.performConnect()
                self.setupReadSource()
                self.connected = true
                IPCLogger.log("IPCClient connected to \(IPCConstants.socketPath)")
                self.callbackQueue.async { [weak self] in
                    self?.onConnect?()
                }
            } catch {
                self.emitError(error)
                self.close()
            }
        }
    }

    func send(_ message: IPCMessage) {
        queue.async {
            guard self.connected else {
                self.emitError(IPCError.notConnected)
                return
            }

            do {
                let data = try IPCCodec.encode(message)
                let result = data.withUnsafeBytes { pointer -> ssize_t in
                    guard let baseAddress = pointer.baseAddress else { return -1 }
                    return write(self.socketFD, baseAddress, data.count)
                }

                if result == -1 {
                    throw IPCError.socketSendFailed(errno: errno)
                }

                IPCLogger.log("IPCClient sent \(message.command.rawValue)")
            } catch {
                self.emitError(error)
            }
        }
    }

    func close() {
        queue.async {
            guard self.socketFD != -1 else { return }

            let fd = self.socketFD
            self.socketFD = -1
            self.connected = false

            if let source = self.readSource {
                self.readSource = nil
                source.cancel()
            } else {
                Darwin.close(fd)
            }
        }
    }

    private func configureSocket(_ fd: Int32) throws {
        var one: Int32 = 1
        if setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout.size(ofValue: one))) == -1 {
            throw IPCError.socketCreationFailed(errno: errno)
        }
        if fcntl(fd, F_SETFL, O_NONBLOCK) == -1 {
            throw IPCError.socketCreationFailed(errno: errno)
        }
    }

    private func performConnect() throws {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)

        let maxPathLength = MemoryLayout.size(ofValue: address.sun_path) / MemoryLayout<CChar>.size
        guard IPCConstants.socketPath.count < maxPathLength else {
            throw IPCError.socketConnectFailed(errno: ENAMETOOLONG)
        }

        IPCConstants.socketPath.withCString { path in
            let length = strlen(path)
            memcpy(&address.sun_path, path, Int(length) + 1)
        }

        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in
                Darwin.connect(self.socketFD, pointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        if result == -1 && errno != EINPROGRESS {
            throw IPCError.socketConnectFailed(errno: errno)
        }
    }

    private func setupReadSource() {
        let source = DispatchSource.makeReadSource(fileDescriptor: socketFD, queue: queue)
        source.setEventHandler { [weak self] in
            self?.handleReadable()
        }
        source.setCancelHandler { [fd = socketFD] in
            Darwin.close(fd)
        }

        readSource = source
        source.resume()
    }

    private func handleReadable() {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(socketFD, &buffer, buffer.count)

        if bytesRead == 0 {
            connected = false
            callbackQueue.async { [weak self] in
                self?.onDisconnect?()
            }
            close()
            return
        }

        if bytesRead < 0 {
            if errno != EWOULDBLOCK && errno != EAGAIN {
                emitError(IPCError.socketReceiveFailed(errno: errno))
                close()
            }
            return
        }

        self.buffer.append(contentsOf: buffer.prefix(bytesRead))

        do {
            var pending = self.buffer
            let messages = try IPCCodec.decodeMessages(from: &pending)
            self.buffer = pending
            messages.forEach { message in
                IPCLogger.log("IPCClient received \(message.command.rawValue) response")
                callbackQueue.async { [weak self] in
                    self?.onMessage?(message)
                }
            }
        } catch {
            emitError(error)
        }
    }

    private func emitError(_ error: Error) {
        IPCLogger.log("IPCClient error: \(error)")
        callbackQueue.async { [weak self] in
            self?.onError?(error)
        }
    }
}
