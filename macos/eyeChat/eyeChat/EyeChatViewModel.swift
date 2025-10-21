//
//  EyeChatViewModel.swift
//  eyeChat
//
//  SwiftUI bridge between the GUI and the daemon IPC client.
//

import Foundation
import Combine

final class EyeChatViewModel: ObservableObject {
    enum MessageRole {
        case system
        case user
        case daemon
    }

    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: MessageRole
        let text: String
    }

    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""
    @Published var isConnected = false
    @Published var statusMessage = "Connecting to eyeChat daemon..."

    private let ipcClient = IPCClient(callbackQueue: .main)
    private let speech = SpeechOutputManager.shared
    private var reconnectWorkItem: DispatchWorkItem?

    init() {
        configureIPC()
    }

    func start() {
        appendSystemMessage("Connecting to eyeChat daemon...")
        ipcClient.connect()
    }

    func stop() {
        reconnectWorkItem?.cancel()
        ipcClient.close()
    }

    func sendCurrentInput() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let message = IPCCommandBuilder.buildMessage(from: trimmed, sender: .gui) else { return }

        guard isConnected else {
            appendSystemMessage("Daemon unavailable. Message not sent.")
            return
        }

        appendUserMessage(trimmed)
        ipcClient.send(message)
        input = ""
    }

    private func configureIPC() {
        ipcClient.onConnect = { [weak self] in
            guard let self else { return }
            self.isConnected = true
            self.statusMessage = "Connected."
            self.appendSystemMessage("Connected to eyeChat daemon.")
        }

        ipcClient.onMessage = { [weak self] message in
            guard let self else { return }

            if let text = message.response?["text"]?.stringValue {
                self.appendDaemonMessage(text)
            } else if let error = message.response?["error"]?.stringValue {
                self.appendSystemMessage("Daemon error: \(error)")
            }

            if message.shouldCloseConnection {
                self.statusMessage = "Daemon closed the connection."
            }
        }

        ipcClient.onError = { [weak self] error in
            guard let self else { return }
            self.statusMessage = "Daemon unavailable. Retrying..."
            self.appendSystemMessage("Daemon not running. Start eyeChatd first.")
            self.scheduleReconnect()
        }

        ipcClient.onDisconnect = { [weak self] in
            guard let self else { return }
            self.isConnected = false
            self.statusMessage = "Lost connection. Reconnecting..."
            self.appendSystemMessage("Lost connection to eyeChat daemon. Attempting to reconnect.")
            self.scheduleReconnect()
        }
    }

    private func appendSystemMessage(_ text: String) {
        messages.append(ChatMessage(role: .system, text: text))
    }

    private func appendUserMessage(_ text: String) {
        messages.append(ChatMessage(role: .user, text: text))
    }

    private func appendDaemonMessage(_ text: String) {
        messages.append(ChatMessage(role: .daemon, text: text))
        speech.speak(text)
    }

    private func scheduleReconnect() {
        reconnectWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.ipcClient.connect()
        }
        reconnectWorkItem = item
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5, execute: item)
    }
}
