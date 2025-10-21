//
//  main.swift
//  eyeChat-cli
//
//  Created by Bruno Pinto on 16/10/2025.
//
import Dispatch
import Foundation

final class CLIRunner {
    private let speech = SpeechOutputManager.shared
    private let inputQueue = DispatchQueue(label: "io.eyeChat.cli.input", qos: .userInteractive)
    private let ipcClient = IPCClient(callbackQueue: .main)
    private var isConnected = false
    private var shouldQuitAfterResponse = false
    private var reconnectWorkItem: DispatchWorkItem?
    private var running = true
    private var hasAnnouncedMissing = false

    init() {
        ipcClient.onConnect = { [weak self] in
            guard let self else { return }
            self.isConnected = true
            self.hasAnnouncedMissing = false
            self.speech.speak("Connected to eyeChat daemon.")
            print("Connected to daemon at \(IPCConstants.socketPath)")
        }

        ipcClient.onError = { [weak self] error in
            guard let self else { return }
            switch error {
            case IPCError.socketConnectFailed, IPCError.socketCreationFailed, IPCError.socketReceiveFailed:
                self.reportDaemonMissing()
                if !self.shouldQuitAfterResponse {
                    self.scheduleReconnect()
                }
            default:
                print("IPC error: \(error)")
            }
        }

        ipcClient.onDisconnect = { [weak self] in
            guard let self else { return }
            self.isConnected = false
            guard !self.shouldQuitAfterResponse else { return }
            self.speech.speak("Lost connection to eyeChat daemon. Attempting to reconnect.")
            print("Daemon connection lost. Reconnecting...")
            self.scheduleReconnect()
        }

        ipcClient.onMessage = { [weak self] message in
            guard let self else { return }
            self.handleResponse(message)
        }
    }

    func start() {
        speech.speak("eyeChat CLI connecting to daemon...")
        connect()

        inputQueue.async { [weak self] in
            self?.processInputLoop()
        }
    }

    private func connect() {
        ipcClient.connect()
    }

    private func scheduleReconnect() {
        reconnectWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.connect()
        }
        reconnectWorkItem = workItem
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func processInputLoop() {
        while running, let line = readLine(strippingNewline: true) {
            handleCommand(line)
        }

        DispatchQueue.main.async {
            self.speech.speak("Input closed. eyeChat CLI exiting.")
            exit(EXIT_SUCCESS)
        }
    }

    private func handleCommand(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch trimmed.lowercased() {
        case "speech on":
            speech.toggleSpeech(true)
        case "speech off":
            speech.toggleSpeech(false)
        case "stop":
            speech.stop()
        default:
            guard let message = IPCCommandBuilder.buildMessage(from: trimmed, sender: .cli) else { return }
            if message.command == .quit {
                shouldQuitAfterResponse = true
            }
            send(message)
        }
    }

    private func send(_ message: IPCMessage) {
        guard isConnected else {
            reportDaemonMissing()
            return
        }

        ipcClient.send(message)
    }

    private func handleResponse(_ message: IPCMessage) {
        if let text = message.response?["text"]?.stringValue {
            print("Daemon: \(text)")
            speech.speak(text)
        } else if let error = message.response?["error"]?.stringValue {
            print("Daemon error: \(error)")
            speech.speak(error)
        }

        if message.shouldCloseConnection || shouldQuitAfterResponse {
            running = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                exit(EXIT_SUCCESS)
            }
        }
    }

    private func reportDaemonMissing() {
        if !isConnected, !hasAnnouncedMissing {
            print("Daemon not running. Start eyeChatd first.")
            hasAnnouncedMissing = true
        }
    }
}

@main
struct EyeChatCLI {
    static func main() {
        let cliRunner = CLIRunner()
        cliRunner.start()
        dispatchMain()
    }
}
