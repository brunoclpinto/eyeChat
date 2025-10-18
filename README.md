# eyeChat

eyeChat is an experimental macOS assistant that combines a chat-first interface with accessibility tooling.  
Current work focuses on a daemon and CLI that provide synthesized speech feedback for every response while preparing the groundwork for forthcoming GUI features.

## Project Layout

```
macos/
 └─ eyeChat/
    ├─ eyeChat/                # SwiftUI macOS app (placeholder)
    ├─ eyeChat-cli/            # Command line interface with default-on speech output
    ├─ eyeChatd/               # Daemon responsible for accessibility integration
    └─ Shared/                 # Shared utilities (SpeechOutputManager, permissions scaffolding)
```

## Implemented Features

- **Speech output subsystem** – `SpeechOutputManager` (shared) reads all textual responses aloud using `AVSpeechSynthesizer`, with a persisted toggle so users can disable speech temporarily or permanently.
- **Accessibility permission flow** – `eyeChatd` checks for macOS Accessibility trust, prompts the user with spoken instructions, and waits until permissions are granted before continuing.
- **CLI speech commands** – The command-line tool echoes typed input, exposes `speech on`, `speech off`, `stop`, and `exit`, and respects the shared speech toggle across sessions.
- **Permissions manager groundwork** – A central `PermissionsManager` already includes stubs for microphone and speech recognition access checks for future phases.

## Prerequisites

- macOS 14 (Sonoma) or later.
- Xcode 15 or later (full install, not just Command Line Tools) to build and run the targets.
- Accessibility permission disabled in **System Settings → Privacy & Security → Developer Tools** for Xcode if you want to see the permission prompt while debugging.

## Building & Running

### eyeChatd (daemon)
1. Open `macos/eyeChat/eyeChat.xcodeproj` in Xcode.
2. Select the `eyeChatd` scheme and run.
3. On first run (outside of Xcode’s inherited permissions) macOS will open the Accessibility settings pane.  
   - Follow the spoken guidance and enable eyeChat under Accessibility.
4. Once enabled, the daemon announces “Accessibility permission granted. eyeChat ready.”

To test the permission flow manually from Terminal, run the compiled binary outside Xcode (e.g., from DerivedData or using `xcodebuild`).

### eyeChat-cli
1. Build via Xcode (scheme `eyeChat-cli`) or from Terminal:  
   ```bash
   cd macos/eyeChat
   xcodebuild -scheme eyeChat-cli -configuration Debug
   ```
2. Execute the binary (e.g. `./Build/Products/Debug/eyeChat-cli`).
3. Available commands:
   - Type any text to have it spoken and printed.
   - `speech on` / `speech off` – toggle synthesized speech while keeping textual output.
   - `stop` – stop the current utterance immediately.
   - `exit` or `quit` – end the session.

Speech enablement state is shared with the daemon via `UserDefaults`, so changes in one component apply globally.

### GUI App

The SwiftUI app target (`eyeChat`) is a placeholder at this phase and does not yet expose functionality. Future milestones will integrate the speech manager and daemon IPC.

## Testing Checklist

- Launching `eyeChatd` without Accessibility permission should prompt, speak instructions, and wait until permissions are granted.
- Running `eyeChat-cli` should speak and print responses by default.
- Toggling speech off/on in either CLI or daemon persists across restarts.
- Running with VoiceOver enabled should not produce conflicts (speech uses `AVSpeechSynthesizer`, not VoiceOver announcements).

## Troubleshooting

- **No permission prompt while running from Xcode**  
  Ensure Xcode isn’t whitelisted under Developer Tools. Otherwise, run the daemon binary directly from Terminal.
- **No audio output**  
  Verify system volume and that another application isn’t monopolizing the audio device.
- **Build errors involving AVFoundation or Speech frameworks**  
  Confirm you are targeting macOS 14+ with the full Xcode SDK; the project uses Swift 5 concurrency features.

---

This README reflects the state of Phase 0.3 (Text-to-Speech Core). Future phases will expand GUI interaction, speech recognition, and application control. Contributions and feedback are welcome!
