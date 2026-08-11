import SwiftUI
import AppKit // Necessario per usare NSWorkspace e le icone di macOS

struct ConversionSettingsView: View {
    // VARIABILI (Dati in ingresso)
    // Questa view ha bisogno di sapere quale file è stato selezionato,
    // quali formati sono disponibili e quale formato è attualmente scelto.
    let fileURL: URL
    let availableFormats: [String]
    
    // @Binding significa "leggo e scrivo una variabile che vive da un'altra parte"
    // (in questo caso vive in MainView)
    @Binding var selectedFormat: String
    
    // PROPRIETÀ CALCOLATA: Estraiamo l'icona vera dal sistema operativo
    private var fileIcon: NSImage {
        // NSWorkspace ci permette di dialogare col sistema (il Finder)
        return NSWorkspace.shared.icon(forFile: fileURL.path)
    }
    
    var body: some View {
        // HStack (Horizontal Stack): Affianca gli elementi da sinistra a destra
        HStack(spacing: 30) {
            
            // -----------------------------------------
            // 1. QUADRATO SINISTRO (File in ingresso)
            // -----------------------------------------
            // VStack (Vertical Stack): Mette l'icona sopra al nome del file
            VStack(spacing: 12) {
                // Mostriamo l'icona vera del sistema
                Image(nsImage: fileIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                
                Text(fileURL.lastPathComponent)
                    .font(.callout)
                    .lineLimit(1) // Massimo una riga
                    .truncationMode(.middle) // Se è lungo, taglia in mezzo (es: mio...ile.png)
                    .frame(maxWidth: 130)
            }
            .padding()
            .frame(width: 160, height: 140)
            // Effetto "Carta": Sfondo leggermente in rilievo con l'ombra
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            
            
            // -----------------------------------------
            // 2. FRECCIA CENTRALE
            // -----------------------------------------
            Image(systemName: "arrow.right")
                .font(.system(size: 30, weight: .bold)) // Icona bella spessa
                .foregroundColor(.secondary) // Colore secondario di sistema (grigetto)
            
            
            // -----------------------------------------
            // 3. QUADRATO DESTRO (Formato in uscita)
            // -----------------------------------------
            VStack(spacing: 15) {
                Text("Converti in:")
                    .font(.headline)
                
                // Il Picker è il menu a tendina
                Picker("", selection: $selectedFormat) {
                    ForEach(availableFormats, id: \.self) { format in
                        Text(format.uppercased()).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden() // Nascondiamo l'etichetta vuota a lato
                .frame(width: 100)
            }
            .padding()
            .frame(width: 160, height: 140)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            
        }
        .padding()
    }
}
