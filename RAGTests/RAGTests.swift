//
//  RAGTests.swift
//  RAGTests
//
//  Created by Eric Collom on 12/15/25.
//

import Testing
import Foundation
import FoundationModels
@testable import RAG

struct RAGTests {
    
    let text = "The quick brown fox jumps over the lazy dog."
    
    @MainActor
    @Test func testAppleNLContextualEmbedderSelfSimilarity() async throws {
        async let embedding1 = EmbeddingService.shared.embed(text: text)
        async let embedding2 = EmbeddingService.shared.embed(text: text)
        let (emb1, emb2) = try await (embedding1, embedding2)
        
        let norm1 = EmbeddingService.shared.normalize(emb1)
        let norm2 = EmbeddingService.shared.normalize(emb2)
        let similarity = VectorSearchService.cosineSimilarity(vectorA: norm1, vectorB: norm2)
        print(similarity)
        #expect(similarity > 0.95)
    }
    
    @MainActor
    @Test func testMiniLML6V2EmbedderSelfSimilarity() async throws {
        guard let embedder = try? await CoreMLTextEmbedder(modelConfig: .miniLML6V2) else {
            print("MiniLML6V2 model not found, skipping test.")
            return
        }
        
        async let embedding1 = embedder.embed(text: text)
        async let embedding2 = embedder.embed(text: text)
        let (emb1, emb2) = try await (embedding1, embedding2)
        
        let norm1 = EmbeddingService.shared.normalize(emb1)
        let norm2 = EmbeddingService.shared.normalize(emb2)
        let similarity = VectorSearchService.cosineSimilarity(vectorA: norm1, vectorB: norm2)
        print(similarity)
        #expect(similarity > 0.95)
    }
    
    @MainActor
    @Test func testE5SmallV2EmbedderSelfSimilarity() async throws {
        guard let embedder = try? await CoreMLTextEmbedder(modelConfig: .e5SmallV2) else {
            print("E5SmallV2 model not found, skipping test.")
            return
        }
        
        async let embedding1 = embedder.embed(text: text)
        async let embedding2 = embedder.embed(text: text)
        let (emb1, emb2) = try await (embedding1, embedding2)
        
        let norm1 = EmbeddingService.shared.normalize(emb1)
        let norm2 = EmbeddingService.shared.normalize(emb2)
        let similarity = VectorSearchService.cosineSimilarity(vectorA: norm1, vectorB: norm2)
        print(similarity)
        #expect(similarity > 0.95)
    }
    
    @Test
    func testEndToEndRAGSearch() async throws {
        let uniquePath = "test_e2e_\(UUID().uuidString).sqlite"
        let service = try await RAGService(dbPath: uniquePath)
        try await service.clearDatabase()
        
        let chunkText = "The quick brown fox jumps over the lazy dog near the riverbank, demonstrating agility and speed."
        try await service.addTextChunk(chunkText)
        
        try await service.reloadIndex()
        
        let results = await service.performRAG(query: chunkText)
        
        #expect(!results.isEmpty, "Results should not be empty")
        if let topResult = results.first {
            #expect(topResult.text == chunkText, "Top result text should exactly match the chunk text")
            #expect(topResult.score >= 0.95, "Top result score should be at least 0.95")
            
            print("Top result score: \(await topResult.score)")
            let preview = await String(topResult.text.prefix(50))
            print("Top result preview: \(preview)")
        } else {
            #expect(false, "No top result found")
        }
    }
}
