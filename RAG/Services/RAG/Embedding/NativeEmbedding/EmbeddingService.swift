//
//  EmbeddingService.swift
//  RAG
//
//  Created by Eric Collom on 12/9/25.
//

import NaturalLanguage
import CoreML
import Accelerate

actor EmbeddingActor {
    private var embeddingModel: NLContextualEmbedding?
    private var isInitialized = false
    private var initializationTask: Task<Void, Error>?
    
    private func initializeModel(language: NLLanguage = .english) async throws {
        if isInitialized && embeddingModel != nil {
            return
        }
        
        // If there's already an initialization in progress, wait for it
        if let existingTask = initializationTask {
            try await existingTask.value
            return
        }
        
        // Start new initialization
        let task = Task<Void, Error> {
            print("🧠 Initializing NLContextualEmbedding model...")
            
            guard let model = NLContextualEmbedding(language: language) else {
                throw EmbeddingError.failedToInitializeNLContextualEmbedding(language.rawValue)
            }
            
            print("🔄 Requesting embedding model assets...")
            try await model.requestAssets()
            print("✅ Embedding model ready")
            
            self.embeddingModel = model
            self.isInitialized = true
        }
        
        self.initializationTask = task
        
        do {
            try await task.value
        } catch {
            self.initializationTask = nil
            throw error
        }
        
        self.initializationTask = nil
    }
    
    func embed(text: String, language: NLLanguage = .english) async throws -> [Double]? {
        try await initializeModel(language: language)
        
        guard let model = embeddingModel else {
            throw EmbeddingError.failedToInitializeNLContextualEmbedding(language.rawValue)
        }
        
        let result = try model.embeddingResult(for: text, language: language)
        return try await EmbeddingService.shared.meanPool(text: text, result: result)
    }
}

class EmbeddingService: EmbeddingProvider {
    typealias VectorElement = Double
    
    // MARK: - Singleton Pattern
    static let shared = EmbeddingService()
    private let embeddingActor = EmbeddingActor()
    
    // Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Public Interface
    
    /// Embed text using the singleton instance
    func embed(text: String, language: NLLanguage = .english) async throws -> [Double]? {
        return try await embeddingActor.embed(text: text, language: language)
    }
    
    // MARK: - EmbeddingProvider Protocol Conformance
    
    /// Instance method version of embed for protocol conformance
    func embed(text: String) async throws -> [Double] {
        guard let embedding = try await embed(text: text, language: .english) else {
            throw EmbeddingError.embeddingWasNil
        }
        
        return embedding
    }
    
    /// Mean pooling of token vectors
    func meanPool(text: String, result: NLContextualEmbeddingResult) throws -> [Double]? {
        let range: Range<String.Index> = text.startIndex..<text.endIndex
        var dimension = 0
        
        // Get the size
        result.enumerateTokenVectors(in: range) { vector, _ in
            dimension = vector.count
            return false
        }
        
        guard dimension > 0 else { throw EmbeddingError.noDimensionsFound }
        var sumVector = [Double](repeating: 0.0, count: dimension)
        var tokenCount = 0
        
        result.enumerateTokenVectors(in: range) { vector, _ in
            for i in 0..<dimension {
                sumVector[i] += vector[i]
            }
            
            tokenCount += 1
            return true
        }
        
        guard tokenCount > 0 else { throw EmbeddingError.tokenCountZero }
        
        return sumVector.map { $0 / Double(tokenCount) }
    }
}


