//
//  SpeechOutputManager.swift
//  eyeChat
//
//  Shared speech output manager for eyeChat apps.
//

import AVFoundation
import Foundation

final class SpeechOutputManager {
    static let shared = SpeechOutputManager()

    private let synthesizer = AVSpeechSynthesizer()
    private var enabled: Bool
    private let defaultsKey = "eyeChat.ttsEnabled"

    private init() {
        enabled = UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    func speak(_ text: String) {
        print(text)

        guard enabled else { return }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func toggleSpeech(_ enabled: Bool) {
        self.enabled = enabled
        UserDefaults.standard.set(enabled, forKey: defaultsKey)

        let status = enabled ? "enabled" : "disabled"
        print("Speech output \(status).")

        if enabled {
            speak("Speech output enabled.")
        } else {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    func isSpeechEnabled() -> Bool {
        enabled
    }
}
