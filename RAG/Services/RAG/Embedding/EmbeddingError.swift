//
//  EmbeddingError.swift
//  RAG
//
//  Created by Eric Collom on 12/9/25.
//

import Foundation

/// Unified error type for all embedding operations across different providers
enum EmbeddingError: Error, LocalizedError {
    // MARK: - NLContextualEmbedding Errors
    case failedToInitializeNLContextualEmbedding(_ language: String)
    case noDimensionsFound
    case tokenCountZero
    case embeddingWasNil
    
    // MARK: - Core ML Model Errors
    case modelNotFound
    case modelLoadingFailed(Error)
    case tokenizationFailed
    case predictionFailed(Error)
    case invalidOutput
    case textTooLong(Int)
    
    var errorDescription: String? {
        switch self {
        // NLContextualEmbedding errors
        case .failedToInitializeNLContextualEmbedding(let language):
            return "Failed to initialize NLContextualEmbedding for language: \(language)"
        case .noDimensionsFound:
            return "No dimensions found in embedding result"
        case .tokenCountZero:
            return "Token count is zero, cannot compute embedding"
        case .embeddingWasNil:
            return "Embedding result was nil"
            
        // Core ML model errors
        case .modelNotFound:
            return "Model not found in app bundle. Please ensure the .mlmodel or .mlmodelc file is added to your project target."
        case .modelLoadingFailed(let error):
            return "Failed to load model: \(error.localizedDescription)"
        case .tokenizationFailed:
            return "Failed to tokenize input text"
        case .predictionFailed(let error):
            return "Model prediction failed: \(error.localizedDescription)"
        case .invalidOutput:
            return "Model returned invalid output"
        case .textTooLong(let length):
            return "Text too long (\(length) characters). Maximum supported length is approximately 5000 characters."
        }
    }
}
