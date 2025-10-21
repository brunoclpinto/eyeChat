//
//  IPCServer.swift
//  eyeChat Shared
//
//  POSIX-based Unix domain socket server that accepts newline-delimited JSON messages.
//

import Foundation
import Darwin

final class IPCServer {
    private let listenQueue = DispatchQueue(label: "io.eyeChat.ipc.server.listen")
    private let clientQueue = DispatchQueue(label: "io.eyeChat.ipc.server.clients", attributes: .concurrent)
    private let stateQueue = DispatchQueue(label: "io.eyeChat.ipc.server.state")

    private var listenFD: Int32 = -1
    private var listenSource: DispatchSourceRead?
    private var clients: [Int32: ClientContext] = [:]
    private var started = false

    private let router: IPCCommandRouter

    init(router: IPCCommandRouter = DefaultIPCCommandRouter()) {
        self.router = router
    }

    deinit {
        stop()
    }

    func start() throws {
        try stateQueue.sync {
            guard !started else {
                throw IPCError.alreadyStarted
            }
            started = true
        }

        try removeStaleSocket()

        listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenFD != -1 else {
            throw IPCError.socketCreationFailed(errno: errno)
        }

        try setSocketOptions(listenFD)
        try bindSocket()
        try setFilePermissions()

        guard listen(listenFD, SOMAXCONN) != -1 else {
            let error = errno
            close(listenFD)
            throw IPCError.socketListenFailed(errno: error)
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: listenFD, queue: listenQueue)
        source.setEventHandler { [weak self] in
            self?.acceptPendingConnections()
        }
        source.setCancelHandler { [listenFD] in
            close(listenFD)
        }

        listenSource = source
        source.resume()

        IPCLogger.log("IPCServer started on \(IPCConstants.socketPath)")
    }

    func stop() {
        stateQueue.sync {
            guard started else { return }
            started = false
        }

        listenSource?.cancel()
        listenSource = nil
        if listenFD != -1 {
            close(listenFD)
            listenFD = -1
        }

        stateQueue.sync {
            clients.values.forEach { $0.source.cancel() }
            clients.removeAll()
        }

        unlink(IPCConstants.socketPath)
        IPCLogger.log("IPCServer stopped")
    }

    private func removeStaleSocket() throws {
        var statBuffer = stat()
        if lstat(IPCConstants.socketPath, &statBuffer) == 0 {
            if (statBuffer.st_mode & S_IFMT) == S_IFSOCK {
                unlink(IPCConstants.socketPath)
            } else {
                throw IPCError.socketBindFailed(errno: EEXIST)
            }
        }
    }

    private func setSocketOptions(_ fd: Int32) throws {
        var one: Int32 = 1
        if setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout.size(ofValue: one))) == -1 {
            throw IPCError.socketCreationFailed(errno: errno)
        }
        if setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout.size(ofValue: one))) == -1 {
            throw IPCError.socketCreationFailed(errno: errno)
        }
        if fcntl(fd, F_SETFL, O_NONBLOCK) == -1 {
            throw IPCError.socketCreationFailed(errno: errno)
        }
    }

    private func bindSocket() throws {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)

        let maxPathLength = MemoryLayout.size(ofValue: address.sun_path) / MemoryLayout<CChar>.size
        guard IPCConstants.socketPath.count < maxPathLength else {
            throw IPCError.socketBindFailed(errno: ENAMETOOLONG)
        }

        IPCConstants.socketPath.withCString { path in
            let length = strlen(path)
            memcpy(&address.sun_path, path, Int(length) + 1)
        }

        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in
                bind(listenFD, pointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        if bindResult == -1 {
            let error = errno
            close(listenFD)
            throw IPCError.socketBindFailed(errno: error)
        }
    }

    private func setFilePermissions() throws {
        if chmod(IPCConstants.socketPath, S_IRUSR | S_IWUSR) == -1 {
            throw IPCError.socketBindFailed(errno: errno)
        }
    }

    private func acceptPendingConnections() {
        while true {
            var address = sockaddr_un()
            var length: socklen_t = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientFD = withUnsafeMutablePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in
                    accept(listenFD, pointer, &length)
                }
            }

            if clientFD == -1 {
                if errno == EWOULDBLOCK || errno == EAGAIN {
                    break
                }

                IPCLogger.log("Accept failed: \(errno)")
                break
            }

            do {
                try setSocketOptions(clientFD)
                try validatePeer(fd: clientFD)
                attachClient(fd: clientFD)
            } catch {
                IPCLogger.log("Rejected client: \(error)")
                close(clientFD)
            }
        }
    }

    private func validatePeer(fd: Int32) throws {
        var credentials = xucred()
        var length = socklen_t(MemoryLayout<xucred>.size)
        let result = withUnsafeMutablePointer(to: &credentials) {
            getsockopt(fd, SOL_LOCAL, LOCAL_PEERCRED, $0, &length)
        }

        guard result == 0 else {
            throw IPCError.unauthorizedPeer
        }

        guard credentials.cr_uid == getuid() else {
            throw IPCError.unauthorizedPeer
        }
    }

    private func attachClient(fd: Int32) {
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: clientQueue)
        let context = ClientContext(fd: fd, source: source)

        source.setEventHandler { [weak self] in
            self?.handleReadableClient(context)
        }
        source.setCancelHandler {
            close(fd)
        }

        stateQueue.async(flags: .barrier) {
            self.clients[fd] = context
        }

        source.resume()
        IPCLogger.log("Accepted client fd \(fd)")
    }

    private func handleReadableClient(_ context: ClientContext) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(context.fd, &buffer, buffer.count)

        if bytesRead == 0 {
            IPCLogger.log("Client fd \(context.fd) closed")
            removeClient(context)
            return
        }

        if bytesRead < 0 {
            if errno != EWOULDBLOCK && errno != EAGAIN {
                IPCLogger.log("Read failed for fd \(context.fd): \(errno)")
                removeClient(context)
            }
            return
        }

        context.append(Data(buffer.prefix(bytesRead)))

        do {
            var pending = context.drainBuffer()
            let messages = try IPCCodec.decodeMessages(from: &pending)
            if !pending.isEmpty {
                context.replaceBuffer(with: pending)
            }

            for message in messages {
                IPCLogger.log("Server received: \(message.command.rawValue) from \(message.sender)")
                let response = router.handle(message: message)
                try send(response, to: context)

                if response.shouldCloseConnection {
                    IPCLogger.log("Closing client fd \(context.fd) on request.")
                    removeClient(context)
                    break
                }
            }
        } catch {
            IPCLogger.log("Failed to decode message from fd \(context.fd): \(error)")
            removeClient(context)
        }
    }

    private func send(_ message: IPCMessage, to context: ClientContext) throws {
        let data = try IPCCodec.encode(message)
        let result = data.withUnsafeBytes { pointer -> ssize_t in
            guard let baseAddress = pointer.baseAddress else { return -1 }
            return write(context.fd, baseAddress, data.count)
        }

        if result == -1 {
            throw IPCError.socketSendFailed(errno: errno)
        }

        IPCLogger.log("Server sent response for \(message.command.rawValue)")
    }

    private func removeClient(_ context: ClientContext) {
        context.source.cancel()

        stateQueue.async(flags: .barrier) {
            self.clients.removeValue(forKey: context.fd)
        }
    }
}

// MARK: - ClientContext

private final class ClientContext {
    let fd: Int32
    let source: DispatchSourceRead
    private var buffer = Data()
    private let bufferQueue = DispatchQueue(label: "io.eyeChat.ipc.server.client.buffer", attributes: .concurrent)

    init(fd: Int32, source: DispatchSourceRead) {
        self.fd = fd
        self.source = source
    }

    func append(_ data: Data) {
        bufferQueue.async(flags: .barrier) {
            self.buffer.append(data)
        }
    }

    func drainBuffer() -> Data {
        bufferQueue.sync {
            buffer
        }
    }

    func replaceBuffer(with data: Data) {
        bufferQueue.async(flags: .barrier) {
            self.buffer = data
        }
    }
}
