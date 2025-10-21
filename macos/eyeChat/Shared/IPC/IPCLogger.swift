//
//  IPCLogger.swift
//  eyeChat Shared
//
//  Minimal logging helper that appends timestamped entries to the shared log file.
//

import Foundation

enum IPCLogger {
    private static let queue = DispatchQueue(label: "io.eyeChat.ipc.logger")

    static func log(_ message: String) {
        queue.async {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(timestamp)] \(message)\n"

            guard let data = line.data(using: .utf8) else {
                return
            }

            let url = URL(fileURLWithPath: IPCConstants.logPath)

            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    do {
                        try handle.seekToEnd()
                        try handle.write(contentsOf: data)
                    } catch {
                        // Intentionally ignore transient logging failures.
                    }
                }
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}
