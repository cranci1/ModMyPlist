//
//  ModMyPlistApp.swift
//  ModMyPlist
//
//  Created by Francesco on 21/04/25.
//

import SwiftUI

@main
struct ModMyPlistApp: App {
    @StateObject private var settings = Settings()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
    }
    
    init() {
        setupCleanupOnExit()
    }
    
    private func setupCleanupOnExit() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            if UserDefaults.standard.bool(forKey: "clearOnExit") {
                clearProcessedIPAs()
            }
        }
    }
    
    private func clearProcessedIPAs() {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for url in contents {
                if url.pathExtension == "ipa" {
                    try? fileManager.removeItem(at: url)
                }
            }
        } catch {
            print("Error clearing IPAs: \(error)")
        }
    }
}