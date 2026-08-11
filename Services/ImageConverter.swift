import Foundation
import AppKit

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
    
    /// NUOVO: La funzione restituisce i dati grezzi (Data) invece di salvare direttamente
    func convert(inputURL: URL, to targetFormat: String) throws -> Data
}

// 1.5 L'ESTENSIONE (Il comportamento di default)
// Tutte le struct che adottano ImageConverter erediteranno questa logica gratis!
extension ImageConverter {
    func convert(inputURL: URL, to targetFormat: String) throws -> Data {
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
        return dataConvertita
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
