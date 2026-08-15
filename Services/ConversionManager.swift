import Foundation

// IL MANAGER (Il direttore d'orchestra)
// Questa classe si occupa di "conoscere" tutti i convertitori disponibili
// e di fornire le informazioni corrette a chi le chiede (come la nostra View).

class ConversionManager {
    // 1. Singleton: creiamo un'unica istanza condivisa di questa classe
    // così non dobbiamo ricrearla ogni volta che ci serve.
    static let shared = ConversionManager()
    
    // 2. La lista di tutte le nostre "sottolibrerie"
    private let converters: [ImageConverter] = [
        PNGConverter(),
        JPGConverter(),
        JPEGConverter(),
        TIFFConverter(),
        TIFConverter(),
        BMPConverter(),
        GIFConverter(),
        JP2Converter(),
        PDFConverter(),
        DOCXConverter(),
        DOCConverter()
    ]
    
    // 3. Il metodo che la View chiamerà per sapere i formati disponibili
    func availableFormats(for extensionName: String) -> [String] {
        let estensione = extensionName.lowercased()
        
        // Cerchiamo nella lista il primo convertitore che ha lo stesso formato sorgente
        if let converter = converters.first(where: { $0.sourceFormat == estensione }) {
            return converter.supportedOutputFormats
        }
        
        // Se non troviamo nulla, restituiamo un array vuoto (formato non supportato)
        return []
    }
    
    // 4. La funzione che esegue effettivamente il lavoro
    func performConversion(fileURL: URL, to targetFormat: String, options: ConversionOptions? = nil) throws -> ConversionResult {
        let estensione = fileURL.pathExtension.lowercased()
        
        // Cerchiamo il convertitore giusto (es: il PNGConverter)
        guard let converter = converters.first(where: { $0.sourceFormat == estensione }) else {
            throw NSError(domain: "ConversionError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Nessun convertitore trovato per il formato \(estensione)."])
        }
        
        // Diciamo a QUEL convertitore di fare il lavoro.
        return try converter.convert(inputURL: fileURL, to: targetFormat, options: options)
    }
}
