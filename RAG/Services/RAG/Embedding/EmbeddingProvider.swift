//
//  EmbeddingProtocol.swift
//  RAG
//
//  Created by Assistant on 12/13/25.
//

import Foundation
import NaturalLanguage
import Accelerate

/// A protocol for text embedding services that can generate vector representations of text
/// for semantic similarity and retrieval tasks.
protocol EmbeddingProvider {
    
    /// The type of vector elements used by this embedding provider (Float or Double)
//    associatedtype VectorElement: BinaryFloatingPoint
    
    /// Generate an embedding vector for the given text
    /// - Parameter text: The input text to embed
    /// - Returns: An array representing the embedding vector
    /// - Throws: An error if embedding generation fails
    func embed(text: String) async throws -> [Double]
    
//    /// Calculate cosine similarity between two embedding vectors
//    /// - Parameters:
//    ///   - vector1: The first embedding vector
//    ///   - vector2: The second embedding vector
//    /// - Returns: Cosine similarity score between -1 and 1
//    func cosineSimilarity(vector1: [Double], vector2: [Double]) -> Double
    
    /// Normalize an embedding vector to unit length
    /// - Parameter vector: The input embedding vector
    /// - Returns: The normalized embedding vector
    func normalize(_ vector: [Double]) -> [Double]
}

// Default implementations
extension EmbeddingProvider {
    func normalize(_ vector: [Double]) -> [Double] {
        var result = vector
        var magnitude: Double = 0.0
        
        // This is very fast, faster than doing it through SQL
        vDSP_svesqD(vector, 1, &magnitude, vDSP_Length(vector.count))
        magnitude = sqrt(magnitude)
        
        if magnitude > 0 {
            var scale = 1.0 / magnitude
            vDSP_vsmulD(vector, 1, &scale, &result, 1, vDSP_Length(vector.count))
        }
        
        return result
    }
}
