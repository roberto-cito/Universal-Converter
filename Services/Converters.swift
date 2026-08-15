import Foundation
import AppKit
import PDFKit

// 1. IL PROTOCOLLO (L'interfaccia)
// Questo è il "contratto". Qualsiasi struttura o classe voglia comportarsi come un
// "convertitore di immagini" dovrà obbligatoriamente avere queste proprietà.
// DEFINIZIONE DEGLI ERRORI
// In Swift è buona pratica creare un enum per catalogare tutti i possibili errori
enum ConversionError: LocalizedError {
    case decodeFailed
    case unsupportedOutputFormat
    case generationFailed
    
    var errorDescription: String? {
        switch self {
        case .decodeFailed: return "Impossibile decodificare l'immagine."
        case .unsupportedOutputFormat: return "Formato di uscita non gestito."
        case .generationFailed: return "Errore durante la generazione dell'immagine."
        }
    }
}

protocol ImageConverter {
    /// Il formato del file originale (es: "png")
    var sourceFormat: String { get }
    
    /// I formati in cui questo convertitore sa trasformare l'immagine
    var supportedOutputFormats: [String] { get }
    
    /// La funzione restituisce i dati grezzi (Data) invece di salvare direttamente
    func convert(inputURL: URL, to targetFormat: String, options: ConversionOptions?) throws -> [Data]
}

// 1.5 L'ESTENSIONE (Il comportamento di default)
// Tutte le struct che adottano ImageConverter erediteranno questa logica gratis!
extension ImageConverter {
    func convert(inputURL: URL, to targetFormat: String, options: ConversionOptions?) throws -> [Data] {
        // Richiediamo i permessi per il Sandbox (per leggere il file di origine)
        let gotAccess = inputURL.startAccessingSecurityScopedResource()
        defer {
            if gotAccess {
                inputURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Se fallisce la lettura, lancia in automatico l'errore del sistema
        let imageData = try Data(contentsOf: inputURL)
        
        guard let image = NSImage(data: imageData),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw ConversionError.decodeFailed
        }
        
        let tipoDiCodifica: NSBitmapImageRep.FileType
        var proprieta: [NSBitmapImageRep.PropertyKey: Any] = [:]
        
        switch targetFormat.lowercased() {
        case "jpg", "jpeg":
            tipoDiCodifica = .jpeg
            proprieta = [.compressionFactor: 0.8]
        case "png":
            tipoDiCodifica = .png
        case "tiff", "tif":
            tipoDiCodifica = .tiff
        case "bmp":
            tipoDiCodifica = .bmp
        case "gif":
            tipoDiCodifica = .gif
        case "jp2":
            tipoDiCodifica = .jpeg2000
        default:
            throw ConversionError.unsupportedOutputFormat
        }
        
        guard let dataConvertita = bitmap.representation(using: tipoDiCodifica, properties: proprieta) else {
            throw ConversionError.generationFailed
        }
        
        // Restituiamo i bit dell'immagine, sarà chi chiama la funzione a decidere dove salvarli!
        return [dataConvertita]
    }
}

// 2. LE SOTTOLIBRERIE (Le implementazioni)
// Aggiornato per supportare tutti i formati nativi esportabili da macOS

struct PNGConverter: ImageConverter {
    let sourceFormat = "png"
    let supportedOutputFormats = ["jpg", "tiff", "bmp", "gif", "jp2"]
}

struct JPGConverter: ImageConverter {
    let sourceFormat = "jpg"
    let supportedOutputFormats = ["png", "tiff", "bmp", "gif", "jp2"]
}

struct JPEGConverter: ImageConverter {
    let sourceFormat = "jpeg"
    let supportedOutputFormats = ["png", "tiff", "bmp", "gif", "jp2"]
}

struct TIFFConverter: ImageConverter {
    let sourceFormat = "tiff"
    let supportedOutputFormats = ["png", "jpg", "bmp", "gif", "jp2"]
}

struct TIFConverter: ImageConverter {
    let sourceFormat = "tif"
    let supportedOutputFormats = ["png", "jpg", "bmp", "gif", "jp2"]
}

struct BMPConverter: ImageConverter {
    let sourceFormat = "bmp"
    let supportedOutputFormats = ["png", "jpg", "tiff", "gif", "jp2"]
}

struct GIFConverter: ImageConverter {
    let sourceFormat = "gif"
    let supportedOutputFormats = ["png", "jpg", "tiff", "bmp", "jp2"]
}

struct JP2Converter: ImageConverter {
    let sourceFormat = "jp2"
    let supportedOutputFormats = ["png", "jpg", "tiff", "bmp", "gif"]
}

struct PDFConverter: ImageConverter {
    let sourceFormat = "pdf"
    let supportedOutputFormats = ["png", "jpg", "tiff", "bmp", "gif", "rtf", "txt", "doc", "docx"]
    
    func convert(inputURL: URL, to targetFormat: String, options: ConversionOptions?) throws -> [Data] {
        let gotAccess = inputURL.startAccessingSecurityScopedResource()
        defer {if gotAccess { inputURL.stopAccessingSecurityScopedResource() }}
        
        guard let pdfDoc = PDFDocument(url: inputURL) else {
            throw ConversionError.decodeFailed
        }
    
        let opts = options ?? ConversionOptions()
        var pagesToProcess: [PDFPage] = []
        
        let totalPages = pdfDoc.pageCount
        
        switch opts.pageMode {
                case "Singola":
                    let idx = min(max(opts.singlePage - 1, 0), totalPages - 1)
                    if let page = pdfDoc.page(at: idx) { pagesToProcess.append(page) }
                case "Range":
                    let start = min(max(opts.startPage - 1, 0), totalPages - 1)
                    let end = min(max(opts.endPage - 1, 0), totalPages - 1)
                    for i in start...end {
                        if let page = pdfDoc.page(at: i) { pagesToProcess.append(page) }
                    }
                default: // "Tutte"
                    for i in 0..<totalPages {
                        if let page = pdfDoc.page(at: i) { pagesToProcess.append(page) }
                    }
                }
        if targetFormat == "txt" {
            let allText = pagesToProcess.compactMap { $0.string }.joined(separator: "\n\n--- Pagina Seguente ---\n\n")
            return [allText.data(using: .utf8) ?? Data()]
        }
        else if targetFormat == "docx" {
            let docxData = try convertWithPythonEngine(inputURL: inputURL, targetExtension: "docx")
            return [docxData]
        }
        else if targetFormat == "rtf" || targetFormat == "doc" {
            let fullAttributedString = NSMutableAttributedString()
            for page in pagesToProcess {
                if let attrString = page.attributedString {
                    fullAttributedString.append(attrString)
                    fullAttributedString.append(NSAttributedString(string: "\n\n"))
                }
            }
            let docType: NSAttributedString.DocumentType
            if targetFormat == "rtf" {
                docType = .rtf
            }
            else {
                docType = .docFormat
            }
            let data = try fullAttributedString.data(from: NSRange(location: 0, length: fullAttributedString.length),
            documentAttributes: [.documentType: docType])
            return [data]
        }
        else {
            var outputDataArray: [Data] = []
            
            let tipoDiCodifica: NSBitmapImageRep.FileType
            var proprieta: [NSBitmapImageRep.PropertyKey: Any] = [:]
            
            switch targetFormat {
                case "jpg", "jpeg":
                    tipoDiCodifica = .jpeg
                    proprieta = [.compressionFactor: 0.8]
                case "png": tipoDiCodifica = .png
                case "tiff", "tif": tipoDiCodifica = .tiff
                case "bmp": tipoDiCodifica = .bmp
                case "gif": tipoDiCodifica = .gif
                case "jp2": tipoDiCodifica = .jpeg2000
                default: throw ConversionError.unsupportedOutputFormat
            }
            
            // Per ogni pagina selezionata, creiamo un'immagine in ALTA RISOLUZIONE!
            for page in pagesToProcess {
                let pageRect = page.bounds(for: .mediaBox)
                
                // I PDF su Mac sono misurati in "Punti" (solitamente 72 punti = 1 pollice).
                // Per avere un'alta risoluzione (tipo 300 DPI), moltiplichiamo la dimensione x4!
                let scaleFactor: CGFloat = 4.0
                let highResSize = CGSize(width: pageRect.width * scaleFactor, height: pageRect.height * scaleFactor)
                
                let finalImage = NSImage(size: highResSize)
                finalImage.lockFocus()
                
                if let ctx = NSGraphicsContext.current?.cgContext {
                    // 1. Sfondo bianco
                    NSColor.white.set()
                    ctx.fill(CGRect(origin: .zero, size: highResSize))
                    
                    // 2. Ingigantiamo la "tela" del pittore prima di disegnare
                    ctx.scaleBy(x: scaleFactor, y: scaleFactor)
                    
                    // 3. Facciamo disegnare la pagina al Mac. Essendo un PDF (vettoriale), 
                    // la disegnerà nitidissima senza sgranare nulla!
                    page.draw(with: .mediaBox, to: ctx)
                }
                
                finalImage.unlockFocus()
                
                // Convertiamo l'immagine nei dati grezzi richiesti e li aggiungiamo all'array
                if let tiffData = finalImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let finalData = bitmap.representation(using: tipoDiCodifica, properties: proprieta) {
                    outputDataArray.append(finalData)
                }
            }
            return outputDataArray
        }
    }
    
    // Funzione segreta per parlare con l'eseguibile Python
    private func convertWithPythonEngine(inputURL: URL, targetExtension: String) throws -> Data {
        guard let enginePath = Bundle.main.path(forResource: "convert_pdf", ofType: nil) else {
            print("Errore: Eseguibile Python non trovato nel bundle.")
            throw ConversionError.generationFailed
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = UUID().uuidString + "." + targetExtension
        let tempFileURL = tempDir.appendingPathComponent(tempFileName)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: enginePath)
        process.arguments = [inputURL.path, tempFileURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            print("Errore nel processo Python interno.")
            throw ConversionError.generationFailed
        }
        
        let outData = try Data(contentsOf: tempFileURL)
        try? FileManager.default.removeItem(at: tempFileURL)
        return outData
    }
}

// 3. IL NUOVO CONVERTITORE DOCX (Per la conversione inversa)
struct DOCXConverter: ImageConverter {
    let sourceFormat = "docx"
    let supportedOutputFormats = ["pdf"]
    
    func convert(inputURL: URL, to targetFormat: String, options: ConversionOptions?) throws -> [Data] {
        let gotAccess = inputURL.startAccessingSecurityScopedResource()
        defer { if gotAccess { inputURL.stopAccessingSecurityScopedResource() } }
        
        guard targetFormat == "pdf" else {
            throw ConversionError.unsupportedOutputFormat
        }
        
        guard let enginePath = Bundle.main.path(forResource: "convert_pdf", ofType: nil) else {
            print("Errore: Eseguibile Python non trovato nel bundle.")
            throw ConversionError.generationFailed
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = UUID().uuidString + ".pdf"
        let tempFileURL = tempDir.appendingPathComponent(tempFileName)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: enginePath)
        process.arguments = [inputURL.path, tempFileURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            print("Errore nel processo Python interno.")
            throw ConversionError.generationFailed
        }
        
        let outData = try Data(contentsOf: tempFileURL)
        try? FileManager.default.removeItem(at: tempFileURL)
        return [outData]
    }
}

// 4. IL NUOVO CONVERTITORE DOC (Per i file Word vecchi)
struct DOCConverter: ImageConverter {
    let sourceFormat = "doc"
    let supportedOutputFormats = ["pdf"]
    
    func convert(inputURL: URL, to targetFormat: String, options: ConversionOptions?) throws -> [Data] {
        let gotAccess = inputURL.startAccessingSecurityScopedResource()
        defer { if gotAccess { inputURL.stopAccessingSecurityScopedResource() } }
        
        guard targetFormat == "pdf" else {
            throw ConversionError.unsupportedOutputFormat
        }
        
        guard let enginePath = Bundle.main.path(forResource: "convert_pdf", ofType: nil) else {
            print("Errore: Eseguibile Python non trovato nel bundle.")
            throw ConversionError.generationFailed
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = UUID().uuidString + ".pdf"
        let tempFileURL = tempDir.appendingPathComponent(tempFileName)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: enginePath)
        process.arguments = [inputURL.path, tempFileURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            print("Errore nel processo Python interno.")
            throw ConversionError.generationFailed
        }
        
        let outData = try Data(contentsOf: tempFileURL)
        try? FileManager.default.removeItem(at: tempFileURL)
        return [outData]
    }
}
