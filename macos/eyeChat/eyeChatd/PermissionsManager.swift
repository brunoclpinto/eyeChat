//
//  PermissionsManager.swift
//  eyeChatd
//
//  Created by Codex on 17/10/2025.
//

import AVFoundation
import Foundation
import Speech

final class PermissionsManager {
    static let shared = PermissionsManager()

    private init() {}

    func ensureAccessibilityTrusted() -> Bool {
        AccessibilityPermission.ensureTrusted()
    }

    func ensureMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func ensureSpeechRecognitionAccess() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default:
            return false
        }
    }
}
