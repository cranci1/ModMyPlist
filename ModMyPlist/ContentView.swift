//
//  ContentView.swift
//  ModMyPlist
//
//  Created by Francesco on 21/04/25.
//

import SwiftUI
import ZIPFoundation
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var ipaURL: URL?
    @State private var extractedPath: URL?
    @State private var plistData: [String: Any]?
    @State private var isShowingDocumentPicker = false
    @State private var isShowingShareSheet = false
    @State private var modifiedIpaURL: URL?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var rawPlistText = ""
    @State private var isEditingRawPlist = false
    
    @State private var bundleIdentifier = ""
    @State private var bundleName = ""
    @State private var bundleVersion = ""
    @State private var bundleShortVersion = ""

    var body: some View {
        NavigationView {
            VStack {
                if ipaURL == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.zipper")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(.blue)
                        
                        Text("Select an IPA file to modify")
                            .font(.headline)
                        
                        Button("Select IPA File") {
                            isShowingDocumentPicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .padding()
                } else if isLoading {
                    ProgressView("Processing...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if isEditingRawPlist {
                    VStack {
                        Text("Edit Info.plist")
                            .font(.headline)
                            .padding(.top)
                        
                        TextEditor(text: $rawPlistText)
                            .font(.system(size: 14, design: .monospaced))
                            .border(Color.gray.opacity(0.2))
                            .padding()
                        
                        HStack {
                            Button("Cancel") {
                                isEditingRawPlist = false
                            }
                            .foregroundColor(.red)
                            
                            Spacer()
                            
                            Button("Save") {
                                saveRawPlist()
                                isEditingRawPlist = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                } else if plistData != nil {
                    Form {
                        Section(header: Text("IPA File")) {
                            Text(ipaURL?.lastPathComponent ?? "")
                                .font(.subheadline)
                        }
                        
                        Section(header: Text("Bundle Info")) {
                            TextField("Bundle ID", text: $bundleIdentifier)
                            TextField("Bundle Name", text: $bundleName)
                            TextField("Version", text: $bundleVersion)
                            TextField("Short Version", text: $bundleShortVersion)
                        }
                        
                        Section {
                            Button("Edit Raw Info.plist") {
                                prepareRawPlistEditor()
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.blue)
                        }
                        
                        Section {
                            Button("Save Changes") {
                                saveChanges()
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            
                            if modifiedIpaURL != nil {
                                Button("Share Modified IPA") {
                                    isShowingShareSheet = true
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            
                            Button("Start Over") {
                                resetState()
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("ModMyPlist")
            .sheet(isPresented: $isShowingDocumentPicker) {
                DocumentPicker(selectedURL: $ipaURL, onSelection: processIPA)
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let url = modifiedIpaURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK") { }
            } message: { errorMessage in
                Text(errorMessage)
            }
        }
    }
    
    func prepareRawPlistEditor() {
        guard let plistData = plistData else { return }
        
        do {
            let plistData = try PropertyListSerialization.data(
                fromPropertyList: plistData,
                format: .xml,
                options: 0
            )
            if let xmlString = String(data: plistData, encoding: .utf8) {
                self.rawPlistText = xmlString
                self.isEditingRawPlist = true
            }
        } catch {
            errorMessage = "Error preparing plist for editing: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func saveRawPlist() {
        guard let extractedPath = extractedPath else { return }
        
        do {
            guard let plistData = rawPlistText.data(using: .utf8) else {
                throw NSError(domain: "ModMyPlist", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to convert text to data"])
            }
            
            let plist = try PropertyListSerialization.propertyList(
                from: plistData,
                options: .mutableContainersAndLeaves,
                format: nil
            )
            
            guard let plistDict = plist as? [String: Any] else {
                throw NSError(domain: "ModMyPlist", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid property list format"])
            }
            
            self.plistData = plistDict
            
            bundleIdentifier = plistDict["CFBundleIdentifier"] as? String ?? ""
            bundleName = plistDict["CFBundleName"] as? String ?? ""
            bundleVersion = plistDict["CFBundleVersion"] as? String ?? ""
            bundleShortVersion = plistDict["CFBundleShortVersionString"] as? String ?? ""
            
            let payloadDir = extractedPath.appendingPathComponent("Payload")
            let appDirs = try FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
            guard let appDir = appDirs.first(where: { $0.pathExtension == "app" }) else {
                throw NSError(domain: "ModMyPlist", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not find .app directory"])
            }
            
            let plistURL = appDir.appendingPathComponent("Info.plist")
            
            try plistData.write(to: plistURL)
            
        } catch {
            errorMessage = "Error saving raw plist: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func processIPA() {
        guard let ipaURL = ipaURL else { return }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                
                try FileManager.default.unzipItem(at: ipaURL, to: tempDir)
                
                let payloadDir = tempDir.appendingPathComponent("Payload", isDirectory: true)
                
                guard let appDirs = try? FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil) else {
                    throw NSError(domain: "ModMyPlist", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find app directory in Payload folder"])
                }
                
                guard let appDir = appDirs.first(where: { $0.pathExtension == "app" }) else {
                    throw NSError(domain: "ModMyPlist", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not find .app directory in Payload folder"])
                }
                
                let plistURL = appDir.appendingPathComponent("Info.plist")
                
                guard let plistDict = NSDictionary(contentsOf: plistURL) as? [String: Any] else {
                    throw NSError(domain: "ModMyPlist", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not read Info.plist"])
                }
                
                DispatchQueue.main.async {
                    extractedPath = tempDir
                    plistData = plistDict
                    
                    bundleIdentifier = plistDict["CFBundleIdentifier"] as? String ?? ""
                    bundleName = plistDict["CFBundleName"] as? String ?? ""
                    bundleVersion = plistDict["CFBundleVersion"] as? String ?? ""
                    bundleShortVersion = plistDict["CFBundleShortVersionString"] as? String ?? ""
                    
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Error processing IPA: \(error.localizedDescription)"
                    showError = true
                    self.ipaURL = nil
                    isLoading = false
                }
            }
        }
    }
    
    func saveChanges() {
        guard let extractedPath = extractedPath else { return }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let payloadDir = extractedPath.appendingPathComponent("Payload")
                let appDirs = try FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
                guard let appDir = appDirs.first(where: { $0.pathExtension == "app" }) else {
                    throw NSError(domain: "ModMyPlist", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not find .app directory"])
                }
                
                let plistURL = appDir.appendingPathComponent("Info.plist")
                
                var updatedPlist = plistData ?? [:]
                updatedPlist["CFBundleIdentifier"] = bundleIdentifier
                updatedPlist["CFBundleName"] = bundleName
                updatedPlist["CFBundleVersion"] = bundleVersion
                updatedPlist["CFBundleShortVersionString"] = bundleShortVersion
                
                let plistDict = updatedPlist as NSDictionary
                plistDict.write(to: plistURL, atomically: true)
                
                let newIpaURL = FileManager.default.temporaryDirectory.appendingPathComponent("modified_\(ipaURL?.lastPathComponent ?? "app.ipa")")
                
                if FileManager.default.fileExists(atPath: newIpaURL.path) {
                    try FileManager.default.removeItem(at: newIpaURL)
                }
                
                try FileManager.default.zipItem(at: payloadDir, to: newIpaURL, shouldKeepParent: true)
                
                DispatchQueue.main.async {
                    modifiedIpaURL = newIpaURL
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Error saving changes: \(error.localizedDescription)"
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    func resetState() {
        if let extractedPath = extractedPath, FileManager.default.fileExists(atPath: extractedPath.path) {
            try? FileManager.default.removeItem(at: extractedPath)
        }
        
        if let modifiedIpaURL = modifiedIpaURL, FileManager.default.fileExists(atPath: modifiedIpaURL.path) {
            try? FileManager.default.removeItem(at: modifiedIpaURL)
        }
        
        ipaURL = nil
        extractedPath = nil
        plistData = nil
        modifiedIpaURL = nil
        bundleIdentifier = ""
        bundleName = ""
        bundleVersion = ""
        bundleShortVersion = ""
        rawPlistText = ""
        isEditingRawPlist = false
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    var onSelection: () -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [UTType.zip]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            let canAccessResource = url.startAccessingSecurityScopedResource()
            
            do {
                let documentsDirectory = FileManager.default.temporaryDirectory
                let localURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
                
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }
                
                try FileManager.default.copyItem(at: url, to: localURL)
                
                parent.selectedURL = localURL
                parent.onSelection()
            } catch {
                print("Error copying file: \(error.localizedDescription)")
            }
            
            if canAccessResource {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
