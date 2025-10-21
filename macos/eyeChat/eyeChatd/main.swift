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
    private static var runtime: EyeChatDaemonRuntime?

    static func main() {
        runtime = EyeChatDaemonRuntime()
        runtime?.start()
        dispatchMain()
    }
}
