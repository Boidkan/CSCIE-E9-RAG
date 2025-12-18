//
//  FileExtractionService.swift
//  RAG
//
//  Created by Eric Collom on 12/11/25.
//

import PDFKit
import Foundation
import GRDB
import NaturalLanguage

struct FileExtractionService {
    private let chunker = Chunker(chunkSize: 1600, overlap: 180)
    
    enum FileExtractionError: Error {
        case fileNotFound(path: String)
        case fileUnreadable(path: String, reason: String)
        case emptyDocument
        case invalidURL(string: String)
    }
    
    func loadDocument(url: URL, ragService: RAGService) async {
        let db = ragService.dbQueue
        let embedder = ragService.embedder
        
        do {
            print("Starting to load document at \(url.absoluteString)")
            
            // Verify file location and accessibility
            try verifyFileLocation(url: url)
            
            let textChunks = try self.processPDF(at: url)
            print("📄 Extracted \(textChunks.count) total chunks from PDF")
            
            let englishChunks = filterEnglishChunks(textChunks)
            print("🔍 Filtered to \(englishChunks.count) English chunks (removed \(textChunks.count - englishChunks.count) non-English chunks)")
            
            var successfulInserts = 0
            var failedInserts = 0
            
            for (index, chunk) in englishChunks.enumerated() {
                do {
                    
                    let vector = try await embedder.embed(text: chunk)
                    
                    let normalized = ragService.embedder.normalize(vector)
                    let record = Chunk(text: chunk, embedding: normalized)
                    
                    try await db.write { dbConn in
                        try record.insert(dbConn)
                    }
                    
                    successfulInserts += 1
                } catch {
                    print("   ❌ Failed to process chunk \(index + 1): \(error)")
                    failedInserts += 1
                }
            }
            
            print("📊 Final result: Successfully added \(successfulInserts) chunks, failed: \(failedInserts)")
            
            // Calculate and display processing statistics
            if !englishChunks.isEmpty {
                let chunkLengths = englishChunks.map { $0.count }
                let totalChars = chunkLengths.reduce(0, +)
                let minChunkLength = chunkLengths.min() ?? 0
                let maxChunkLength = chunkLengths.max() ?? 0
                let avgChunkLength = totalChars / chunkLengths.count
                
                print("📈 Processing Statistics:")
                print("   Total characters processed: \(totalChars)")
                print("   Chunks processed: \(englishChunks.count)")
                print("   Min chunk length: \(minChunkLength) characters")
                print("   Max chunk length: \(maxChunkLength) characters")
                print("   Avg chunk length: \(avgChunkLength) characters")
                print("   Success rate: \(String(format: "%.1f", Double(successfulInserts) / Double(englishChunks.count) * 100))%")
            }
            
        } catch let error {
            print("FileExtractionService Hit error \(error)")
        }
    }
    
    private func filterEnglishChunks(_ chunks: [String]) -> [String] {
        let languageRecognizer = NLLanguageRecognizer()
        var englishChunks: [String] = []
        var languageStats: [String: Int] = [:]
        
        for chunk in chunks {
            // Skip very short chunks as they're unreliable for language detection
            guard chunk.trimmingCharacters(in: .whitespacesAndNewlines).count > 20 else {
                continue
            }
            
            languageRecognizer.processString(chunk)
            let dominantLanguage = languageRecognizer.dominantLanguage
            
            // Track language statistics for debugging
            let langCode = dominantLanguage?.rawValue ?? "unknown"
            languageStats[langCode, default: 0] += 1
            
            // Only keep English chunks
            if dominantLanguage == .english {
                englishChunks.append(chunk)
            } else {
                // Debug: Show what we're filtering out
                let preview = String(chunk.prefix(80)) + (chunk.count > 80 ? "..." : "")
                print("   🚫 Filtered out \(langCode): \"\(preview)\"")
            }
            
            languageRecognizer.reset()
        }
        
        print("📈 Language distribution:")
        for (lang, count) in languageStats.sorted(by: { $0.value > $1.value }) {
            print("   \(lang): \(count) chunks")
        }
        
        return englishChunks
    }
    
    /// Verifies where the PDF file is located and whether it's accessible
    func verifyFileLocation(url: URL) throws {
        print("🔍 Verifying PDF location...")
        print("   URL scheme: \(url.scheme ?? "none")")
        print("   URL path: \(url.path)")
        print("   Absolute string: \(url.absoluteString)")
        print("   Is file URL: \(url.isFileURL)")
        
        // Check if this is a proper file URL
        if !url.isFileURL {
            // Try to find the file in common locations
            let fileName = url.lastPathComponent
            let possibleLocations = getPossibleFileLocations(fileName: fileName)
            
            print("   File is not a file URL. Searching in common locations:")
            for location in possibleLocations {
                print("   Checking: \(location.path)")
                if FileManager.default.fileExists(atPath: location.path) {
                    print("   ✅ Found file at: \(location.path)")
                    throw FileExtractionError.fileNotFound(path: "File found at \(location.path). Use this URL instead: \(location.absoluteString)")
                }
            }
            
            throw FileExtractionError.invalidURL(string: url.absoluteString)
        }
        
        // Check if file exists
        let fileManager = FileManager.default
        let path = url.path
        
        print("   Checking if file exists at path: \(path)")
        
        guard fileManager.fileExists(atPath: path) else {
            print("   ❌ File does not exist at path: \(path)")
            
            // Search for the file in common locations
            let fileName = url.lastPathComponent
            let possibleLocations = getPossibleFileLocations(fileName: fileName)
            
            print("   Searching for '\(fileName)' in common locations:")
            for location in possibleLocations {
                print("   Checking: \(location.path)")
                if fileManager.fileExists(atPath: location.path) {
                    print("   ✅ Found file at: \(location.path)")
                    throw FileExtractionError.fileNotFound(path: "File found at \(location.path). Use this URL instead: \(location.absoluteString)")
                }
            }
            
            throw FileExtractionError.fileNotFound(path: path)
        }
        
        // Check if file is readable
        guard fileManager.isReadableFile(atPath: path) else {
            print("   ❌ File exists but is not readable at path: \(path)")
            throw FileExtractionError.fileUnreadable(path: path, reason: "File permissions deny read access")
        }
        
        // Get file attributes for additional info
        if let attributes = try? fileManager.attributesOfItem(atPath: path) {
            let fileSize = attributes[.size] as? Int64 ?? 0
            let modificationDate = attributes[.modificationDate] as? Date
            print("   ✅ File verified successfully")
            print("   File size: \(fileSize) bytes")
            if let modDate = modificationDate {
                print("   Last modified: \(modDate)")
            }
        }
    }
    
    /// Returns possible locations where a file might be stored
    private func getPossibleFileLocations(fileName: String) -> [URL] {
        var locations: [URL] = []
        
        // Bundle resources (most common for app resources)
        if let bundlePath = Bundle.main.path(forResource: fileName.components(separatedBy: ".").first, 
                                           ofType: fileName.components(separatedBy: ".").last) {
            locations.append(URL(fileURLWithPath: bundlePath))
        }
        
        // Documents directory
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                       in: .userDomainMask).first {
            locations.append(documentsPath.appendingPathComponent(fileName))
        }
        
        // Desktop (macOS)
        #if os(macOS)
        if let desktopPath = FileManager.default.urls(for: .desktopDirectory, 
                                                     in: .userDomainMask).first {
            locations.append(desktopPath.appendingPathComponent(fileName))
        }
        #endif
        
        // Downloads directory
        if let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, 
                                                       in: .userDomainMask).first {
            locations.append(downloadsPath.appendingPathComponent(fileName))
        }
        
        // Current working directory
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        locations.append(currentDir.appendingPathComponent(fileName))
        
        return locations
    }
    
    private func processPDF(at url: URL) throws -> [String] {
        // Load
        guard let document = PDFDocument(url: url) else {
            throw FileExtractionError.fileUnreadable(path: url.path, reason: "PDFDocument could not load the file - may be corrupted or not a valid PDF")
        }
        
        // Extract Text
        var fullText: String = ""
        let pageCount = document.pageCount
        
        for i in 0..<pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        
        if fullText.isEmpty { throw FileExtractionError.emptyDocument }
        let cleanedText = fullText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        let chunks = chunker.chunk(cleanedText)
        
        print("✅ Processed PDF. Extracted \(fullText.count) chars. Created \(chunks.count) chunks")
        
        return chunks
    }
}

