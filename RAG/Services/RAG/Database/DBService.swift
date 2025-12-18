//
//  DBService.swift
//  RAG
//
//  Created by Eric Collom on 12/8/25.
//


import GRDB

class DBService {
    
    private let embedder: any EmbeddingProvider
    
    init() {
        self.embedder = EmbeddingService.shared
    }
    
    init(embedder: any EmbeddingProvider) {
        self.embedder = embedder
    }
    
    func saveDocument(text: String, dbQueue: DatabaseQueue) async throws {
        let vector = try await embedder.embed(text: text)
        let normalizedVector = EmbeddingService.shared.normalize(vector)
        
        let chunk = Chunk(text: text, embedding: normalizedVector)
        
        try dbQueue.inDatabase { db in
            try chunk.insert(db)
        }
    }
}
