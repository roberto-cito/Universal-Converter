//
//  MainView.swift
//  UniversalCoverter
//
//  Created by Roberto Cito on 11/08/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct FileDropZoneView: View {
    @State private var selectedFileURL: URL?
    @State private var isHovering = false
    @State private var showFilePicker = false
    @State private var statusMessage: String = ""
    @State private var conversionOptions = ConversionOptions()
    

    
    @State private var availableOutputFormats: [String] = []
    @State private var selectedOutputFormat: String = ""

    var body: some View {
        VStack(spacing: 20) {
            
            if let url = selectedFileURL, !availableOutputFormats.isEmpty {
                // MOSTRA SOLO LA NUOVA VIEW (Sostituzione totale)
                VStack(spacing: 10) { // <-- Ridotto lo spazio per evitare il taglio
                    ConversionSettingsView(
                        fileURL: url,
                        availableFormats: availableOutputFormats,
                        selectedFormat: $selectedOutputFormat,
                        options: $conversionOptions
                    )
                    
                    // IL NUOVO BOTTONE DI CONVERSIONE
                    Button(action: {
                        do {
                            // 1. Ora riceviamo un ConversionResult!
                            let conversionResult = try ConversionManager.shared.performConversion(fileURL: url, to: selectedOutputFormat, options: conversionOptions)
                            let dataArray = conversionResult.outputData
                            
                            if dataArray.isEmpty { throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nessun dato generato."]) }
                            
                            if dataArray.count == 1 {
                                // --- CASO A: SINGOLO FILE ---
                                let savePanel = NSSavePanel()
                                savePanel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + "." + selectedOutputFormat
                                savePanel.directoryURL = url.deletingLastPathComponent()
                                
                                if savePanel.runModal() == .OK, let saveURL = savePanel.url {
                                    try dataArray[0].write(to: saveURL)
                                    if let warning = conversionResult.warningMessage {
                                        self.statusMessage = warning
                                    } else {
                                        self.statusMessage = "✅ Salvato con successo"
                                    }
                                }
                            } else {
                                // --- CASO B: FILE MULTIPLI (Cartella) ---
                                let openPanel = NSOpenPanel()
                                openPanel.canChooseFiles = false
                                openPanel.canChooseDirectories = true // Scegliamo una cartella di destinazione
                                openPanel.canCreateDirectories = true
                                openPanel.message = "Scegli dove salvare la cartella con le immagini convertite"
                                openPanel.directoryURL = url.deletingLastPathComponent()
                                
                                if openPanel.runModal() == .OK, let folderURL = openPanel.url {
                                    // Creiamo la sottocartella
                                    let folderName = "Converted_" + url.deletingPathExtension().lastPathComponent
                                    let destinationFolder = folderURL.appendingPathComponent(folderName)
                                    
                                    try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
                                    
                                    // Salviamo ogni singola pagina
                                    for (index, fileData) in dataArray.enumerated() {
                                        let fileName = "\(index + 1).\(selectedOutputFormat)"
                                        let fileURL = destinationFolder.appendingPathComponent(fileName)
                                        try fileData.write(to: fileURL)
                                    }
                                    
                                    if let warning = conversionResult.warningMessage {
                                        self.statusMessage = warning
                                    } else {
                                        self.statusMessage = "✅ Salvate \(dataArray.count) immagini"
                                    }
                                }
                            }
                            
                            // Ripuliamo la GUI se è un successo puro (non un warning e non un errore)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                if self.statusMessage.contains("✅") {
                                    self.selectedFileURL = nil
                                    self.statusMessage = ""
                                }
                            }
                        } catch {
                            self.statusMessage = "❌ Errore: \(error.localizedDescription)"
                        }
                    }) {
                        Label("Converti in \(selectedOutputFormat.uppercased())", systemImage: "wand.and.stars")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(width: 280)
                    .padding(.top, 10)
                    
                    // MESSAGGIO DI ERRORE/SUCCESSO DELLA CONVERSIONE
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .foregroundColor(statusMessage.contains("❌") ? .red : (statusMessage.contains("⚠️") ? .orange : .green))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 5)
                    }
                    
                    // Bottone "Scegli un altro file" migliorato con icona e stile nativo
                    Button(role: .cancel) {
                        // Resettiamo le variabili per tornare alla schermata iniziale
                        self.selectedFileURL = nil
                        self.availableOutputFormats = []
                        self.selectedOutputFormat = ""
                    } label: {
                        Label("Scegli un altro file", systemImage: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            } else {
                // MOSTRA L'AREA DI DRAG & DROP (Solo se non c'è un file selezionato)
                VStack(spacing: 15) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 50))
                        .foregroundColor(isHovering ? .blue : .gray)
                    
                    Text("Trascina qui un file supportato\noppure clicca per selezionarlo")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                }
                .padding(40)
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(isHovering ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(isHovering ? Color.blue : Color.gray, style: StrokeStyle(lineWidth: 2, dash: [8]))
                )
                .onTapGesture { showFilePicker = true }
                .onDrop(of: [UTType.fileURL], isTargeted: $isHovering) { providers in
                    if let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) {
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url = url {
                                DispatchQueue.main.async {
                                    validaEConverti(url)
                                }
                            }
                        }
                        return true
                    }
                    return false
                }
                
                // MESSAGGIO DI ERRORE
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .foregroundColor(.red)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                .image,
                .pdf,
                UTType(filenameExtension: "docx") ?? .data,
                UTType(filenameExtension: "doc") ?? .data
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    validaEConverti(url)
                }
            case .failure(let error):
                self.statusMessage = "❌ Errore selezione: \(error.localizedDescription)"
            }
        }
        .navigationTitle("Universal Converter")
    }
    
    // MARK: - VERIFICA FORMATO DI CONVERSIONE
    
    // 1. VALIDA IL FILE
    private func validaEConverti(_ url: URL) {
        let estensione = url.pathExtension.lowercased()
        
        // Chiediamo al nostro nuovo manager i formati disponibili!
        let formatiPermessi = ConversionManager.shared.availableFormats(for: estensione)
        
        if !formatiPermessi.isEmpty {
            self.selectedFileURL = url
            self.availableOutputFormats = formatiPermessi
            
            // Impostiamo il primo formato della lista come selezione di default per il Picker
            self.selectedOutputFormat = formatiPermessi.first ?? ""
            
            // Abbiamo rimosso il messaggio di successo, la nuova view fa già capire che il file è pronto.
            self.statusMessage = ""
            
        } else {
            self.selectedFileURL = nil
            self.availableOutputFormats = []
            self.selectedOutputFormat = ""
            self.statusMessage = "❌ Formato '.\(estensione)' non supportato."
        }
    }
}
