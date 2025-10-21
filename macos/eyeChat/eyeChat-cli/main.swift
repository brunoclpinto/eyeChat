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

    func start() {
        speech.speak("eyeChat CLI ready. Type commands, or 'speech on', 'speech off', 'stop', 'exit'.")

        inputQueue.async { [weak self] in
            self?.processInputLoop()
        }
    }

    private func processInputLoop() {
        while let line = readLine(strippingNewline: true) {
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
        case "exit", "quit":
            speech.speak("Goodbye.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                exit(EXIT_SUCCESS)
            }
        case "speech on":
            speech.toggleSpeech(true)
        case "speech off":
            speech.toggleSpeech(false)
        case "stop":
            speech.stop()
        default:
            speech.speak(trimmed)
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
