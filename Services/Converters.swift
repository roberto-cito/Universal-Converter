import Foundation
import AppKit
import PDFKit

// 1. IL PROTOCOLLO (L'interfaccia)
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

struct ConversionResult {
    let outputData: [Data]
    let warningMessage: String?
}

protocol ImageConverter {
    var sourceFormat: String { get }
    var supportedOutputFormats: [String] { get }
    func convert(inputURL: URL, to targetFormat: String, options: ConversionOptions?) throws -> ConversionResult
}

// 1.5 L'ESTENSIONE (Il comportamento di default)
extension ImageConverter {
    func convert(inputURL: URL, to targetFormat: String, options: ConversionOptions?) throws -> ConversionResult {
        let gotAccess = inputURL.startAccessingSecurityScopedResource()
        defer {
            if gotAccess {
                inputURL.stopAccessingSecurityScopedResource()
            }
        }
        
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
        
        return ConversionResult(outputData: [dataConvertita], warningMessage: nil)
    }
}

// 2. LE SOTTOLIBRERIE
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
    let supportedOutputFormats = ["pdf", "png", "jpg", "tiff", "bmp", "gif", "rtf", "txt", "doc", "docx", "html"]
    
    func convert(inputURL: URL, to targetFormat: String, options: ConversionOptions?) throws -> ConversionResult {
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
        default:
            for i in 0..<totalPages {
                if let page = pdfDoc.page(at: i) { pagesToProcess.append(page) }
            }
        }
        
        if targetFormat == "pdf" {
            let newPdf = PDFDocument()
            for page in pagesToProcess {
                if let copy = page.copy() as? PDFPage {
                    newPdf.insert(copy, at: newPdf.pageCount)
                }
            }
            if let newData = newPdf.dataRepresentation() {
                return ConversionResult(outputData: [newData], warningMessage: nil)
            } else {
                throw ConversionError.generationFailed
            }
        }
        else if targetFormat == "txt" {
            let allText = pagesToProcess.compactMap { $0.string }.joined(separator: "\n\n--- Pagina Seguente ---\n\n")
            return ConversionResult(outputData: [allText.data(using: .utf8) ?? Data()], warningMessage: nil)
        }
        else if targetFormat == "docx" {
            let docxData = try convertWithPythonEngine(inputURL: inputURL, targetExtension: "docx")
            return ConversionResult(outputData: [docxData], warningMessage: nil)
        }
        else if targetFormat == "html" {
            let htmlData = try convertWithHtmlEngine(inputURL: inputURL, targetExtension: "html")
            return ConversionResult(outputData: [htmlData], warningMessage: nil)
        }
        else if targetFormat == "rtf" || targetFormat == "doc" || targetFormat == "html" {
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
            else if targetFormat == "doc" {
                docType = .docFormat
            }
            else {
                docType = .html
            }
            let data = try fullAttributedString.data(from: NSRange(location: 0, length: fullAttributedString.length),
            documentAttributes: [.documentType: docType])
            return ConversionResult(outputData: [data], warningMessage: nil)
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
            
            for page in pagesToProcess {
                let pageRect = page.bounds(for: .mediaBox)
                let scaleFactor: CGFloat = 4.0
                let highResSize = CGSize(width: pageRect.width * scaleFactor, height: pageRect.height * scaleFactor)
                
                let finalImage = NSImage(size: highResSize)
                finalImage.lockFocus()
                
                if let ctx = NSGraphicsContext.current?.cgContext {
                    NSColor.white.set()
                    ctx.fill(CGRect(origin: .zero, size: highResSize))
                    ctx.scaleBy(x: scaleFactor, y: scaleFactor)
                    page.draw(with: .mediaBox, to: ctx)
                }
                
                finalImage.unlockFocus()
                
                if let tiffData = finalImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let finalData = bitmap.representation(using: tipoDiCodifica, properties: proprieta) {
                    outputDataArray.append(finalData)
                }
            }
            return ConversionResult(outputData: outputDataArray, warningMessage: nil)
        }
    }
    
    private func convertWithPythonEngine(inputURL: URL, targetExtension: String) throws -> Data {
        guard let enginePath = Bundle.main.path(forResource: "convert_pdf", ofType: nil) else {
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
            throw ConversionError.generationFailed
        }
        
        let outData = try Data(contentsOf: tempFileURL)
        try? FileManager.default.removeItem(at: tempFileURL)
        return outData
    }
    
    private func convertWithHtmlEngine(inputURL: URL, targetExtension: String) throws -> Data {
        guard let enginePath = Bundle.main.path(forResource: "convert_html", ofType: nil) else {
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
            throw ConversionError.generationFailed
        }
        
        let outData = try Data(contentsOf: tempFileURL)
        try? FileManager.default.removeItem(at: tempFileURL)
        return outData
    }
}

// Funzione helper per il fallback testuale da DOC/DOCX a PDF
func nativeFallbackWordToPDF(inputURL: URL, docType: NSAttributedString.DocumentType) throws -> ConversionResult {
    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: docType]
    let attrStr = try NSAttributedString(url: inputURL, options: options, documentAttributes: nil)
    
    let printInfo = NSPrintInfo.shared
    printInfo.jobDisposition = .save
    let tempPDFURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
    printInfo.dictionary().setObject(tempPDFURL, forKey: NSPrintInfo.AttributeKey.jobSavingURL as NSCopying)
    
    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: printInfo.paperSize.width, height: printInfo.paperSize.height))
    textView.textStorage?.setAttributedString(attrStr)
    
    let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
    printOperation.showsPrintPanel = false
    printOperation.showsProgressPanel = false
    
    // NSPrintOperation deve girare nel thread principale
    DispatchQueue.main.sync {
        printOperation.run()
    }
    
    let data = try Data(contentsOf: tempPDFURL)
    try? FileManager.default.removeItem(at: tempPDFURL)
    
    return ConversionResult(
        outputData: [data],
        warningMessage: "⚠️ Microsoft Word non trovato o fallito. Conversione testuale (senza immagini) applicata."
    )
}

func convertWordDocument(inputURL: URL, targetFormat: String, options: ConversionOptions?, docType: NSAttributedString.DocumentType) throws -> ConversionResult {
    var pdfData: Data
    var finalWarning: String? = nil
    
    if let enginePath = Bundle.main.path(forResource: "convert_pdf", ofType: nil) {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = UUID().uuidString + ".pdf"
        let tempFileURL = tempDir.appendingPathComponent(tempFileName)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: enginePath)
        process.arguments = [inputURL.path, tempFileURL.path]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                pdfData = try Data(contentsOf: tempFileURL)
                try? FileManager.default.removeItem(at: tempFileURL)
            } else {
                let fallback = try nativeFallbackWordToPDF(inputURL: inputURL, docType: docType)
                pdfData = fallback.outputData[0]
                finalWarning = fallback.warningMessage
            }
        } catch {
            let fallback = try nativeFallbackWordToPDF(inputURL: inputURL, docType: docType)
            pdfData = fallback.outputData[0]
            finalWarning = fallback.warningMessage
        }
    } else {
        let fallback = try nativeFallbackWordToPDF(inputURL: inputURL, docType: docType)
        pdfData = fallback.outputData[0]
        finalWarning = fallback.warningMessage
    }
    
    if targetFormat == "pdf" && (options?.pageMode == "Tutte" || options == nil) {
        return ConversionResult(outputData: [pdfData], warningMessage: finalWarning)
    }
    
    let tempPDF = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
    try pdfData.write(to: tempPDF)
    defer { try? FileManager.default.removeItem(at: tempPDF) }
    
    let pdfConverter = PDFConverter()
    let extractionResult = try pdfConverter.convert(inputURL: tempPDF, to: targetFormat, options: options)
    
    return ConversionResult(outputData: extractionResult.outputData, warningMessage: finalWarning)
}

struct DOCXConverter: ImageConverter {
    let sourceFormat = "docx"
    let supportedOutputFormats = ["pdf", "png", "jpg", "jpeg", "tiff", "bmp", "gif", "jp2"]
    
    func convert(inputURL: URL, to targetFormat: String, options: ConversionOptions?) throws -> ConversionResult {
        let gotAccess = inputURL.startAccessingSecurityScopedResource()
        defer { if gotAccess { inputURL.stopAccessingSecurityScopedResource() } }
        return try convertWordDocument(inputURL: inputURL, targetFormat: targetFormat, options: options, docType: .officeOpenXML)
    }
}

struct DOCConverter: ImageConverter {
    let sourceFormat = "doc"
    let supportedOutputFormats = ["pdf", "png", "jpg", "jpeg", "tiff", "bmp", "gif", "jp2"]
    
    func convert(inputURL: URL, to targetFormat: String, options: ConversionOptions?) throws -> ConversionResult {
        let gotAccess = inputURL.startAccessingSecurityScopedResource()
        defer { if gotAccess { inputURL.stopAccessingSecurityScopedResource() } }
        return try convertWordDocument(inputURL: inputURL, targetFormat: targetFormat, options: options, docType: .docFormat)
    }
}

struct HTMLConverter: ImageConverter {
    let sourceFormat = "html"
    let supportedOutputFormats = ["pdf"]
    
    func convert(inputURL: URL, to targetFormat: String, options: ConversionOptions?) throws -> ConversionResult {
        let gotAccess = inputURL.startAccessingSecurityScopedResource()
        defer { if gotAccess { inputURL.stopAccessingSecurityScopedResource() } }
        
        if targetFormat == "pdf" {
            let pdfData = try convertWithHtmlEngine(inputURL: inputURL, targetExtension: "pdf")
            return ConversionResult(outputData: [pdfData], warningMessage: nil)
        } else {
            throw ConversionError.unsupportedOutputFormat
        }
    }
    
    private func convertWithHtmlEngine(inputURL: URL, targetExtension: String) throws -> Data {
        guard let enginePath = Bundle.main.path(forResource: "convert_html", ofType: nil) else {
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
            throw ConversionError.generationFailed
        }
        
        let outData = try Data(contentsOf: tempFileURL)
        try? FileManager.default.removeItem(at: tempFileURL)
        return outData
    }
}

