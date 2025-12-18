//
//  RAGService.swift
//  RAG
//
//  Created by Eric Collom on 12/8/25.
//

import FoundationModels
import Combine
import GRDB
import Foundation

class RAGService {
    
    var dbQueue: DatabaseQueue
    var searchService: VectorSearchService
    var embedder: EmbeddingProvider
    
    public static let shared: RAGService = {
        do {
            return try RAGService()
        } catch {
            fatalError("Failed to initialize RAGService singleton: \(error)")
        }
    }()
    
    init(dbPath: String = "db_v1.sqlite") throws {
        self.embedder = EmbeddingService.shared
        // Get the Documents directory path for iOS compatibility
        let documentsPath = try FileManager.default.url(for: .documentDirectory,
                                                        in: .userDomainMask,
                                                        appropriateFor: nil,
                                                        create: true)
        let dbPath = documentsPath.appendingPathComponent(dbPath).path
        
        self.dbQueue = try DatabaseQueue(path: dbPath)
        
        // Setup DB
        try dbQueue.write { db in
            // Create the chunk table if it doesn't exist
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS chunk (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    text TEXT NOT NULL,
                    embedding BLOB NOT NULL
                )
            """)
        }
        
        self.searchService = VectorSearchService(dbQueue: dbQueue, embedder: embedder)
        try self.searchService.loadIndex()
    }
    
    init(embedder: EmbeddingProvider, dbPath: String) throws {
        // Get the Documents directory path for iOS compatibility
        let documentsPath = try FileManager.default.url(for: .documentDirectory,
                                                        in: .userDomainMask,
                                                        appropriateFor: nil,
                                                        create: true)
        let fullDbPath = documentsPath.appendingPathComponent(dbPath).path
        
        self.embedder = embedder
        self.dbQueue = try DatabaseQueue(path: fullDbPath)
        
        // Setup DB
        try dbQueue.write { db in
            // Create the chunk table if it doesn't exist
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS chunk (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    text TEXT NOT NULL,
                    embedding BLOB NOT NULL
                )
            """)
        }
        
        self.searchService = VectorSearchService(dbQueue: dbQueue, embedder: embedder)
        try self.searchService.loadIndex()
    }
    
    func reloadIndex() throws {
        try searchService.loadIndex()
        print("Reloaded search index with \(searchService.index.count) items")
    }
    
    func addDocument(at url: URL) async throws {
        let fileService = FileExtractionService()
        await fileService.loadDocument(url: url, ragService: self)
        try reloadIndex()
    }
    
    func addTextChunk(_ text: String) async throws {
        let dbService = DBService(embedder: self.embedder)
        try await dbService.saveDocument(text: text, dbQueue: dbQueue)
        try reloadIndex()
    }
    
    func getChunkCount() async throws -> Int {
        return try await dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM chunk") ?? 0
        }
    }
    
    func loadFridgePDF() async throws {
        // Try to find fridge.pdf in common locations
        guard let pdfURL = findFridgePDF() else {
            throw NSError(domain: "RAGService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find fridge.pdf. Please ensure it's in your app bundle, Documents directory, or current working directory."])
        }
        
        print("🔄 Starting PDF loading process...")
        print("Loading fridge.pdf from: \(pdfURL.path)")
        print("🌍 Language filtering: Only English chunks will be added to the database")
        
        // Check initial database state
        let initialCount = try await getChunkCount()
        print("📊 Initial database count: \(initialCount) chunks")
        
        // Test embedding service before processing PDF - but only with one simple test
        print("🧪 Testing embedding service with a simple test...")
        do {
            let testEmbedding = try await embedder.embed(text: "Test")
            print("✅ Embedding service working - generated \(testEmbedding.count) dimensional vector")
        } catch {
            print("❌ Embedding service failed: \(error)")
            throw error
        }
        
        try await addDocument(at: pdfURL)
        
        let finalCount = try await getChunkCount()
        print("📊 Final database count: \(finalCount) chunks (added \(finalCount - initialCount))")
        
        if finalCount == initialCount {
            print("⚠️ WARNING: No new chunks were added to the database!")
            print("   This could indicate:")
            print("   1. PDF could not be read")
            print("   2. No English content was found")
            print("   3. Embedding generation failed")
            print("   4. Database insertion failed")
        } else {
            print("✅ Successfully loaded fridge.pdf with \(finalCount - initialCount) new English chunks")
        }
        
        // Sample some chunks to verify content quality
        try await sampleChunks()
    }
    
    private func sampleChunks() async throws {
        print("🔍 Sampling chunks to verify quality:")
        try await dbQueue.read { db in
            let rows = try Row.fetchCursor(db, sql: "SELECT id, text FROM chunk LIMIT 3")
            var count = 0
            while let row = try rows.next() {
                count += 1
                if let id: Int64 = row["id"], let text: String = row["text"] {
                    let preview = String(text.prefix(150)) + (text.count > 150 ? "..." : "")
                    print("   Sample \(count): ID \(id) - \"\(preview)\"")
                }
            }
        }
    }
    
    private func findFridgePDF() -> URL? {
        let fileName = "fridge"
        let fileExtension = "pdf"
        
        // 1. Check app bundle first
        if let bundlePath = Bundle.main.path(forResource: fileName, ofType: fileExtension) {
            print("Found fridge.pdf in app bundle: \(bundlePath)")
            return URL(fileURLWithPath: bundlePath)
        }
        
        // 2. Check Documents directory
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docURL = documentsPath.appendingPathComponent("fridge.pdf")
            if FileManager.default.fileExists(atPath: docURL.path) {
                print("Found fridge.pdf in Documents: \(docURL.path)")
                return docURL
            }
        }
        
        // 3. Check current working directory
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let currentURL = currentDir.appendingPathComponent("fridge.pdf")
        if FileManager.default.fileExists(atPath: currentURL.path) {
            print("Found fridge.pdf in current directory: \(currentURL.path)")
            return currentURL
        }
        
        // 4. Check Desktop (macOS only)
        #if os(macOS)
        if let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            let desktopURL = desktopPath.appendingPathComponent("fridge.pdf")
            if FileManager.default.fileExists(atPath: desktopURL.path) {
                print("Found fridge.pdf on Desktop: \(desktopURL.path)")
                return desktopURL
            }
        }
        #endif
        
        // 5. Check Downloads directory
        if let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            let downloadsURL = downloadsPath.appendingPathComponent("fridge.pdf")
            if FileManager.default.fileExists(atPath: downloadsURL.path) {
                print("Found fridge.pdf in Downloads: \(downloadsURL.path)")
                return downloadsURL
            }
        }
        
        print("⚠️ fridge.pdf not found in any of the following locations:")
        print("   - App bundle")
        print("   - Documents directory: \(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? "unknown")")
        print("   - Current directory: \(FileManager.default.currentDirectoryPath)")
        #if os(macOS)
        print("   - Desktop: \(FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path ?? "unknown")")
        #endif
        print("   - Downloads: \(FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "unknown")")
        
        return nil
    }
    
    func clearDatabase() async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM chunk")
        }
        
        // Reload the index to reflect the empty database
        try reloadIndex()
        
        print("Database cleared successfully - all chunks removed")
    }
    
    func debugEmbeddingService() async {
        print("🔧 Debugging Embedding Service for \(String(describing: type(of: embedder)))...")
        
        let testTexts = [
            "This is a test sentence.",
            "Another test with different content."
        ]
        
        for (index, text) in testTexts.enumerated() {
            print("Testing text \(index + 1): '\(text)'")
            
            do {
                let startTime = CFAbsoluteTimeGetCurrent()
                
                let embedding = try await embedder.embed(text: text)
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = endTime - startTime
                
                print("  ✅ Success: \(embedding.count) dimensions, took \(String(format: "%.2f", duration))s")
                
                // Check if vector looks reasonable
                let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
                let firstFew = Array(embedding.prefix(3))
                print("  📊 Magnitude: \(String(format: "%.4f", magnitude)), First 3 values: \(firstFew.map { String(format: "%.4f", $0) })")
                
            } catch {
                print("  ❌ Error: \(error)")
                break // Stop on first error to avoid overwhelming the service
            }
        }
    }
    
    func performRAG(query: String) async -> [ChunkWithScore] {
        do {
            let rawVector = try await embedder.embed(text: query)
            
            let topResults = searchService.searchWithScores(queryVector: rawVector, limit: 5)
            
            var results: [ChunkWithScore] = []
            
            try await dbQueue.read { db in
                for (index, (id, score)) in topResults.enumerated() {
                    if let chunk = try Chunk.fetchOne(db, key: id) {
                        let chunkPreview = String(chunk.text.prefix(100)) + (chunk.text.count > 100 ? "..." : "")
                        print("   Result \(index + 1): ID \(id), Score: \(String(format: "%.4f", score)) - \"\(chunkPreview)\"")
                        results.append(ChunkWithScore(chunk: chunk, score: score))
                    } else {
                        print("   ⚠️ Warning: Could not fetch chunk with ID: \(id)")
                    }
                }
            }
            
            if results.isEmpty {
                print("   ❌ No results found - this suggests either:")
                print("      1. No data in database (run 'Load Fridge PDF')")
                print("      2. Very poor similarity scores")
                print("      3. Embedding or search issue")
            }
            
            return results
        } catch {
            print("❌ Error in performRAG: \(error)")
            return []
        }
    }
}
