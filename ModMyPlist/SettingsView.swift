//
//  SettingsView.swift
//  ModMyPlist
//
//  Created by Francesco on 22/04/25.
//

import SwiftUI

class Settings: ObservableObject {
    @AppStorage("showOutputView") var showOutputView: Bool = false
    @AppStorage("clearOnExit") var clearOnExit: Bool = true
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Output")) {
                    Toggle("Show Output View", isOn: $settings.showOutputView)
                }
                
                Section(header: Text("Cleanup")) {
                    Toggle("Clear Processed IPAs on Exit", isOn: $settings.clearOnExit)
                    
                    Button("Clear All Processed IPAs Now", role: .destructive) {
                        clearProcessedIPAs()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    func clearProcessedIPAs() {
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
