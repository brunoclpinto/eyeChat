//
//  DaemonRuntime.swift
//  eyeChatd
//
//  Bootstraps permissions and IPC server lifecycle for the daemon.
//

import Foundation
import ApplicationServices

final class EyeChatDaemonRuntime {
    private let permissionsManager = PermissionsManager.shared
    private let server = IPCServer()
    private var signalSources: [DispatchSourceSignal] = []

    func start() {
        guard ensureAccessibilityPermissions() else {
            SpeechOutputManager.shared.speak("Failed to acquire accessibility permission. eyeChat daemon cannot continue.")
            exit(EXIT_FAILURE)
        }

        do {
            try server.start()
        } catch {
            SpeechOutputManager.shared.speak("Failed to start IPC server: \(error)")
            IPCLogger.log("Fatal: \(error)", category: "daemon")
            exit(EXIT_FAILURE)
        }

        SpeechOutputManager.shared.speak("eyeChat daemon ready.")
        installSignalHandlers()
    }

    private func ensureAccessibilityPermissions() -> Bool {
        if permissionsManager.ensureAccessibilityTrusted() {
            return true
        }

        SpeechOutputManager.shared.speak("Waiting for Accessibility permission...")
        while !AXIsProcessTrusted() {
            sleep(3)
        }

        SpeechOutputManager.shared.speak("Accessibility permission granted.")
        return true
    }

    private func installSignalHandlers() {
        let stopHandler: (Int32) -> Void = { [weak self] signal in
            IPCLogger.log("Received signal \(signal). Shutting down.", category: "daemon")
            self?.shutdown()
        }

        [SIGINT, SIGTERM].forEach { sig in
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                stopHandler(sig)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private func shutdown() {
        signalSources.forEach { $0.cancel() }
        signalSources.removeAll()
        server.stop()
        exit(EXIT_SUCCESS)
    }
}
