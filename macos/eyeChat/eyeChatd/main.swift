//
//  main.swift
//  eyeChatd
//
//  Created by Bruno Pinto on 16/10/2025.
//

import ApplicationServices
import Foundation

@main
struct EyeChatDaemon {
    static func main() {
        let permissionsManager = PermissionsManager.shared

        if !permissionsManager.ensureAccessibilityTrusted() {
            SpeechOutputManager.shared.speak("Waiting for Accessibility permission...")
            while !AXIsProcessTrusted() {
                sleep(3)
            }
        }

        SpeechOutputManager.shared.speak("Accessibility permission granted. eyeChat ready.")

        // Continue daemon initialization...
    }
}
