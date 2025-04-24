//
//  ContentView.swift
//  ModMyPlist
//
//  Created by Francesco on 21/04/25.
//

import SwiftUI
import ZIPFoundation
import UniformTypeIdentifiers

struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(radius: 5)
    }
}

struct ProcessingError: LocalizedError {
    let description: String
    
    var errorDescription: String? {
        description
    }
    
    static let invalidIPA = ProcessingError(description: "The selected file is not a valid IPA")
    static let missingInfoPlist = ProcessingError(description: "Could not find Info.plist in the IPA")
    static let invalidInfoPlist = ProcessingError(description: "The Info.plist file is corrupted or invalid")
    static let extractionFailed = ProcessingError(description: "Failed to extract the IPA file")
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.secondary.opacity(0.1))
            .foregroundColor(.primary)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

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
    
    @StateObject private var settings = Settings()
    @State private var isShowingSettings = false
    @State private var outputMessages: [String] = []
    
    @State private var processingProgress: Double = 0
    @State private var processingStage: String = ""
    
    var hasArcadeKey: Bool {
        guard let plistData = plistData else { return false }
        return plistData["NSApplicationRequiresArcade"] != nil
    }
    
    var isArcadePatched: Bool {
        guard let plistData = plistData,
              let arcadeValue = plistData["NSApplicationRequiresArcade"] as? Bool else {
            return false
        }
        return !arcadeValue
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if ipaURL == nil {
                    welcomeView
                } else if isLoading {
                    loadingView
                } else if isEditingRawPlist {
                    rawPlistEditorView
                } else if plistData != nil {
                    ScrollView {
                        VStack(spacing: 20) {
                            ipaInfoCard
                            bundleInfoCard
                            if hasArcadeKey {
                                arcadePatchCard
                            }
                            actionsCard
                            if settings.showOutputView {
                                outputLogCard
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("ModMyPlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isShowingSettings = true }) {
                        Image(systemName: "gear")
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(settings: settings)
            }
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
    
    private var welcomeView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "doc.zipper")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.quaternary)
                    .overlay {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.accentColor)
                            .background(.background)
                            .clipShape(Circle())
                            .offset(x: 30, y: 30)
                    }
                
                Text("Select an IPA file to modify")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Button(action: { isShowingDocumentPicker = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Select IPA File")
                    }
                    .font(.headline)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("ModMyPlist v1.0")
                    .font(.headline)
                Text("© cranci1, GPL v3.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: processingProgress, total: 1.0)
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
            
            Text(processingStage)
                .font(.headline)
            
            Text("Please wait...")
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var rawPlistEditorView: some View {
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
    }
    
    private var ipaInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.accentColor)
                Text("IPA File")
                    .font(.headline)
            }
            
            Divider()
            
            Text(ipaURL?.lastPathComponent ?? "")
                .font(.system(.body, design: .monospaced))
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Ready to modify")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .modifier(GlassBackground())
    }
    
    private var bundleInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "textformat.alt")
                    .foregroundColor(.gray)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Bundle ID")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("Bundle ID", text: $bundleIdentifier)
                }
            }
            
            HStack {
                Image(systemName: "tag")
                    .foregroundColor(.gray)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Bundle Name")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("Bundle Name", text: $bundleName)
                }
            }
            
            HStack {
                Image(systemName: "123.rectangle")
                    .foregroundColor(.gray)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Version")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("Version", text: $bundleShortVersion)
                }
            }
            
            HStack {
                Image(systemName: "number")
                    .foregroundColor(.gray)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Build")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("Build", text: $bundleVersion)
                }
            }
        }
        .padding()
        .modifier(GlassBackground())
    }
    
    private var arcadePatchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Auto Patches")
                    .font(.headline)
            }
            
            Divider()
            
            Button(action: {
                applyArcadePatch()
            }) {
                HStack {
                    Image(systemName: isArcadePatched ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isArcadePatched ? .green : .red)
                    Text("Patch Arcade Game")
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .modifier(GlassBackground())
    }
    
    private var actionsCard: some View {
        Section() {
            Button("Edit Raw Info.plist") {
                prepareRawPlistEditor()
            }
            
            Button("Save Changes") {
                saveChanges()
            }
            .foregroundColor(.green)
            
            if modifiedIpaURL != nil {
                Button("Share Modified IPA") {
                    isShowingShareSheet = true
                }
                .foregroundColor(.green)
            }
            
            Button("Start Over") {
                resetState()
            }
            .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .modifier(GlassBackground())
    }
    
    private var outputLogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.accentColor)
                Text("Output Log")
                    .font(.headline)
            }
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(outputMessages, id: \.self) { message in
                        Text(message)
                            .font(.system(.footnote, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .modifier(GlassBackground())
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
        processingProgress = 0
        processingStage = "Preparing..."
        addOutputMessage("Processing IPA file: \(ipaURL.lastPathComponent)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard ipaURL.pathExtension.lowercased() == "ipa" else {
                    throw ProcessingError.invalidIPA
                }
                
                processingProgress = 0.2
                processingStage = "Extracting IPA..."
                
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                try FileManager.default.unzipItem(at: ipaURL, to: tempDir)
                
                processingProgress = 0.4
                processingStage = "Locating app bundle..."
                
                let payloadDir = tempDir.appendingPathComponent("Payload")
                guard let appDirs = try? FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil),
                      let appDir = appDirs.first(where: { $0.pathExtension == "app" }) else {
                    throw ProcessingError.extractionFailed
                }
                
                processingProgress = 0.6
                processingStage = "Reading Info.plist..."
                
                let plistURL = appDir.appendingPathComponent("Info.plist")
                guard let plistDict = NSDictionary(contentsOf: plistURL) as? [String: Any] else {
                    throw ProcessingError.invalidInfoPlist
                }
                
                processingProgress = 0.8
                processingStage = "Loading data..."
                
                DispatchQueue.main.async {
                    extractedPath = tempDir
                    self.plistData = plistDict
                    
                    bundleIdentifier = plistDict["CFBundleIdentifier"] as? String ?? ""
                    bundleName = plistDict["CFBundleName"] as? String ?? ""
                    bundleVersion = plistDict["CFBundleVersion"] as? String ?? ""
                    bundleShortVersion = plistDict["CFBundleShortVersionString"] as? String ?? ""
                    
                    processingProgress = 1.0
                    processingStage = "Complete"
                    isLoading = false
                    addOutputMessage("IPA processed successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    showError = true
                    self.ipaURL = nil
                    isLoading = false
                    addOutputMessage("Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func saveChanges() {
        guard let extractedPath = extractedPath else { return }
        
        isLoading = true
        addOutputMessage("Saving changes...")
        
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
                    addOutputMessage("Changes saved successfully")
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
        
        isLoading = true
        addOutputMessage("Applying Arcade patch...")
        
        currentPlist["NSApplicationRequiresArcade"] = false
        plistData = currentPlist
        
        addOutputMessage("Arcade patch applied successfully")
        saveChanges()
    }
    
    func addOutputMessage(_ message: String) {
        outputMessages.append("\(Date().formatted(date: .omitted, time: .standard)): \(message)")
    }
    
    var processMessage: String {
        if hasArcadeKey && isArcadePatched {
            return "Applying patch..."
        }
        return "Processing..."
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
