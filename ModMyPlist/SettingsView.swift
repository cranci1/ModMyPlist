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
    @Published var lastCleanupDate: Date?
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) var dismiss
    @State private var showingCleanupConfirmation = false
    @State private var cleanupSuccess = false
    @State private var cleanupMessage = ""
    
    var body: some View {
        NavigationView {
            Form {                
                Section(header: Text("Output")) {
                    Toggle(isOn: $settings.showOutputView) {
                        HStack {
                            Image(systemName: "terminal")
                                .foregroundColor(.green)
                            Text("Show Output View")
                        }
                    }
                }
                
                Section(header: Text("Cleanup")) {
                    Toggle(isOn: $settings.clearOnExit) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Processed IPAs on Exit")
                        }
                    }
                    
                    Button(action: { showingCleanupConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash.circle.fill")
                                .foregroundColor(.red)
                            Text("Clear All Processed IPAs Now")
                        }
                    }
                    
                    if let lastCleanup = settings.lastCleanupDate {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text("Last cleanup: \(lastCleanup.formatted())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
            .alert("Clear Processed IPAs", isPresented: $showingCleanupConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearProcessedIPAs()
                }
            } message: {
                Text("Are you sure you want to clear all processed IPA files? This action cannot be undone.")
            }
            .alert("Cleanup Result", isPresented: $cleanupSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(cleanupMessage)
            }
        }
    }
    
    func clearProcessedIPAs() {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        var filesRemoved = 0
        var errorOccurred = false
        
        do {
            let tempContents = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for url in tempContents where url.pathExtension == "ipa" {
                try fileManager.removeItem(at: url)
                filesRemoved += 1
            }
            
            let docContents = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            for url in docContents where url.pathExtension == "ipa" {
                try fileManager.removeItem(at: url)
                filesRemoved += 1
            }
            
            settings.lastCleanupDate = Date()
            cleanupMessage = "Successfully removed \(filesRemoved) IPA file\(filesRemoved == 1 ? "" : "s")"
        } catch {
            errorOccurred = true
            cleanupMessage = "Error while cleaning up: \(error.localizedDescription)"
        }
        
        cleanupSuccess = true
    }
}