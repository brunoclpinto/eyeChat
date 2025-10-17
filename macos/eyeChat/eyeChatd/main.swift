//
//  main.swift
//  eyeChatd
//
//  Created by Bruno Pinto on 16/10/2025.
//

import ApplicationServices
import Foundation

struct EyeChatDaemon {
    static func main() {
        let permissionsManager = PermissionsManager.shared

        if !permissionsManager.ensureAccessibilityTrusted() {
            print("Waiting for Accessibility permission...")
            while !AXIsProcessTrusted() {
                sleep(3)
            }
        }

        let successMessage = "Accessibility permission granted. eyeChat ready."
        print(successMessage)
        SpeechOutputManager.shared.speak(successMessage)

        // Continue daemon initialization...
    }
}
