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

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        performOnSynthesizer { synth in
            synth.speak(utterance)
        }
    }

    func stop() {
        performOnSynthesizer { synth in
            if synth.isSpeaking {
                synth.stopSpeaking(at: .immediate)
            }
        }
    }

    func toggleSpeech(_ enabled: Bool) {
        self.enabled = enabled
        UserDefaults.standard.set(enabled, forKey: defaultsKey)

        let status = enabled ? "enabled" : "disabled"
        print("Speech output \(status).")

        if enabled {
            speak("Speech output enabled.")
        } else {
            stop()
        }
    }

    func isSpeechEnabled() -> Bool {
        enabled
    }

    private func performOnSynthesizer(_ action: @escaping (AVSpeechSynthesizer) -> Void) {
        if Thread.isMainThread {
            action(synthesizer)
        } else {
            DispatchQueue.main.async {
                action(self.synthesizer)
            }
        }
    }
}
