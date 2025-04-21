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
    
    var hasArcadeKey: Bool {
        guard let plistData = plistData else { return false }
        return plistData["NSApplicationRequiresArcade"] != nil
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if ipaURL == nil {
                    VStack(spacing: 24) {
                        Image(systemName: "doc.zipper")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .foregroundColor(.blue)
                            .shadow(color: .blue.opacity(0.3), radius: 10)
                        
                        Text("Select an IPA file to modify")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Button(action: {
                            isShowingDocumentPicker = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Select IPA File")
                            }
                            .font(.headline)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .blue.opacity(0.3), radius: 5)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text("ModMyPlist v1.0, © cranci1, GPL v3.0")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 16)
                    }
                    .padding()
                } else if isLoading {
                    VStack {
                        ProgressView("Processing...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.2)
                            .padding()
                        Text("Please wait...")
                            .foregroundColor(.secondary)
                    }
                } else if isEditingRawPlist {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Edit Info.plist")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            Button(action: { isEditingRawPlist = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .imageScale(.large)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        
                        ScrollView {
                            VStack(alignment: .leading) {
                                Text("Raw XML")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                TextEditor(text: $rawPlistText)
                                    .font(.system(size: 14, design: .monospaced))
                                    .frame(minHeight: 300)
                                    .padding(8)
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                                
                                Text("Note: Be careful when editing raw XML. Invalid changes may cause issues.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.vertical)
                        
                        Divider()
                        
                        HStack(spacing: 16) {
                            Button(action: { isEditingRawPlist = false }) {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            
                            Button(action: {
                                saveRawPlist()
                                isEditingRawPlist = false
                            }) {
                                Text("Save Changes")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                } else if plistData != nil {
                    Form {
                        Section(header: Text("IPA File")) {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ipaURL?.lastPathComponent ?? "")
                                        .font(.headline)
                                    Text("Ready to modify")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        Section(header: Text("Bundle Info")) {
                            HStack {
                                Image(systemName: "textformat.alt")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                TextField("Bundle ID", text: $bundleIdentifier)
                            }
                            
                            HStack {
                                Image(systemName: "tag")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                TextField("Bundle Name", text: $bundleName)
                            }
                            
                            HStack {
                                Image(systemName: "number")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                TextField("Version", text: $bundleVersion)
                            }
                            
                            HStack {
                                Image(systemName: "123.rectangle")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                TextField("Short Version", text: $bundleShortVersion)
                            }
                        }
                        
                        if hasArcadeKey {
                            Section(header: Text("Auto Patches")) {
                                Button("Patch Arcade Games") {
                                    applyArcadePatch()
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.blue)
                            }
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
    
    func applyArcadePatch() {
        guard var currentPlist = plistData else { return }
        currentPlist["NSApplicationRequiresArcade"] = false
        
        plistData = currentPlist
        saveChanges()
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
