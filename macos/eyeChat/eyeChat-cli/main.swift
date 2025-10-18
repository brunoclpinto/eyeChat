//
//  main.swift
//  eyeChat-cli
//
//  Created by Bruno Pinto on 16/10/2025.
//

import Foundation

func runCLI() {
    let speech = SpeechOutputManager.shared
    speech.speak("eyeChat CLI ready. Type commands, or 'speech on', 'speech off', 'stop', 'exit'.")

    while let line = readLine(strippingNewline: true) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case "exit", "quit":
            speech.speak("Goodbye.")
            return
        case "speech on":
            speech.toggleSpeech(true)
        case "speech off":
            speech.toggleSpeech(false)
        case "stop":
            speech.stop()
        case "":
            continue
        default:
            speech.speak(trimmed)
        }
    }
}

runCLI()
