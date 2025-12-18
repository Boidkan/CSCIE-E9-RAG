//
//  VectorSearchService.swift
//  RAG
//
//  Created by Eric Collom on 12/10/25.
//

import Foundation
import GRDB
import Accelerate

class VectorSearchService {
    struct IndexItem {
        let id: Int64
        let vector: [Double]
    }
    
    private(set) var index: [IndexItem] = []
    private let dbQueue: DatabaseQueue
    private let embedder: EmbeddingProvider
    
    init(dbQueue: DatabaseQueue, embedder: any EmbeddingProvider) {
        self.dbQueue = dbQueue
        self.embedder = embedder
    }
    
    // Loads vectors into memory
    func loadIndex() throws {
        print("Loading vector index...")
        index.removeAll() // Clear existing index
        
        try dbQueue.inDatabase { db in
            let rows = try Row.fetchCursor(db, sql: "SELECT id, embedding FROM chunk")
            
            while let row = try rows.next() {
                if let id: Int64 = row["id"],
                   let data: Data = row["embedding"] {
                    
                    let vector = try JSONDecoder().decode([Double].self, from: data)
                    
                    let normalizedVector = embedder.normalize(vector)
                    index.append(IndexItem(id: id, vector: normalizedVector))
                }
            }
            
        }
    }
    
    func search(queryVector: [Double], limit: Int = 3) -> [Int64] {
        // Ensure query vector is normalized
        let normalizedQueryVector = embedder.normalize(queryVector)
        
        let scores = index.map { item -> (Int64, Double) in
            // Since both vectors are normalized, dot product = cosine similarity
            var cosineSimilarity: Double = 0
            vDSP_dotprD(normalizedQueryVector, 1, item.vector, 1, &cosineSimilarity, vDSP_Length(normalizedQueryVector.count))
            return (item.id, cosineSimilarity)
        }
        
        // Sort by highest similarity (closest to 1.0)
        let sortedScores = scores.sorted { $0.1 > $1.1 }
        
        // Debug: Print top scores to understand similarity quality
        print("🔍 Top search scores:")
        for (index, (id, score)) in sortedScores.prefix(5).enumerated() {
            print("   \(index + 1). ID: \(id), Score: \(String(format: "%.4f", score))")
        }
        
        let topMatches = sortedScores
            .prefix(limit)
            .map(\.0)
        
        return topMatches
    }
    
    func searchWithScores(queryVector: [Double], limit: Int = 3) -> [(Int64, Double)] {
        let normalizedQueryVector = embedder.normalize(queryVector)
        
        let scores = index.map { item -> (Int64, Double) in
            let cosineSimilarity = VectorSearchService.cosineSimilarity(vectorA: normalizedQueryVector, vectorB: item.vector)
            return (item.id, cosineSimilarity)
        }
        
        return scores
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { ($0.0, $0.1) }
    }
    
    // Hardcoded steps of 1
    static func cosineSimilarity(vectorA: [Double], vectorB: [Double]) -> Double {
        var dotProduct: Double = 0
        vDSP_dotprD(vectorA, 1, vectorB, 1, &dotProduct, vDSP_Length(vectorA.count))
        
        return dotProduct
    }
}

