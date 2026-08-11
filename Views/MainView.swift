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
    
    // Hashmap delle conversioni permesse
    let conversionMap: [String: [String]] = [
        "png": ["jpg", "tiff", "bmp"],
        "jpg": ["png", "tiff", "bmp"],
        "jpeg": ["png", "tiff", "bmp"],
        "tiff": ["png", "jpg", "bmp"]
    ]
    
    @State private var availableOutputFormats: [String] = []
    @State private var selectedOutputFormat: String = ""

    var body: some View {
        VStack(spacing: 20) {
            
            // AREA DI DRAG & DROP
            VStack(spacing: 15) {
                Image(systemName: selectedFileURL != nil ? "doc.fill.badge.checkmark" : "arrow.down.doc")
                    .font(.system(size: 50))
                    .foregroundColor(isHovering ? .blue : .gray)
                
                if let url = selectedFileURL {
                    Text("File convertito con successo:")
                        .font(.headline)
                    Text(url.lastPathComponent)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Trascina qui un file supportato\noppure clicca per selezionarla")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                }
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
            

            
            // MESSAGGIO DI STATO (Prende il posto del bottone)
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .foregroundColor(statusMessage.contains("❌") ? .red : .green)
                    .font(.headline) // Più visibile per confermare il successo
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image],
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
        
        if let formatiPermessi = conversionMap[estensione] {
            self.selectedFileURL = url
            self.availableOutputFormats = formatiPermessi
            
            // Mostra semplicemente che il file è pronto
            self.statusMessage = "✅ File selezionato: \(url.lastPathComponent)"
            
        } else {
            self.selectedFileURL = nil
            self.availableOutputFormats = []
            self.selectedOutputFormat = ""
            self.statusMessage = "❌ Formato '.\(estensione)' non supportato."
        }
    }
}
