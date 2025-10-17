//
//  SpeechOutputManager.swift
//  eyeChatd
//
//  Created by Codex on 17/10/2025.
//

import AVFoundation

final class SpeechOutputManager {
    static let shared = SpeechOutputManager()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
}
