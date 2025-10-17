//
//  AccessibilityPermission.swift
//  eyeChatd
//
//  Created by Codex on 17/10/2025.
//

import ApplicationServices
import Foundation

enum AccessibilityPermission {
    /// Ensures the daemon has Accessibility trust, prompting and guiding the user when needed.
    static func ensureTrusted() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: CFDictionary = [promptKey: true] as CFDictionary
        let trustedAfterPrompt = AXIsProcessTrustedWithOptions(options)

        if !trustedAfterPrompt {
            let guidance = "Accessibility permission required. Please open System Settings, Privacy and Security, Accessibility, and enable eyeChat."
            print(guidance)
            SpeechOutputManager.shared.speak(guidance)
        }

        return trustedAfterPrompt
    }
}
