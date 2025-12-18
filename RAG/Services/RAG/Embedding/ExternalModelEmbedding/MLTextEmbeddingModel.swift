//
//  FoundationModelsSessionManager.swift
//  RAG
//
//  Created by Eric Collom on 12/13/25.
//

import Foundation

/// Enum representing different CoreML text embedding models with their configurations.
/// This centralizes model configurations and provides a clean interface for initializing embedders.
public enum MLTextEmbeddingModel {
    case miniLML6V2
    case e5SmallV2
    
    /// The model name (without file extension) to look for in the bundle
    public var modelName: String {
        switch self {
        case .miniLML6V2:
            return "all-MiniLM-L6-v2"
        case .e5SmallV2:
            return "e5-small-v2"
        }
    }
    
    public var tokenizationFolderName: String {
        switch self {
        case .miniLML6V2:
            return "MiniLM"
        case .e5SmallV2:
            return "e5_small_v2"
        }
    }
    
    /// The filename of the tokenization JSON for this model in the bundle
    public var bundleTokenizationFileName: String {
        switch self {
        case .miniLML6V2:
            return "miniLM_tokenizer.json"  // Adjust if different
        case .e5SmallV2:
            return "e5_small_v2_tokenizer.json"
        }
    }
    
    /// The filename of the tokenization configuration JSON for this model in the bundle
    public var bundleTokenizationConfigFileName: String {
        switch self {
        case .miniLML6V2:
            return "miniLM_tokenizer_config.json"  // Adjust if different
        case .e5SmallV2:
            return "e5_small_v2_tokenizer_config.json"
        }
    }
    
    /// The expected filename for the tokenization JSON in the tokenizer folder
    public var tokenizerFileName: String {
        return "tokenizer.json"
    }
    
    /// The expected filename for the tokenization configuration JSON in the tokenizer folder
    public var tokenizerConfigFileName: String {
        return "tokenizer_config.json"
    }
    
    /// Maximum sequence length for tokenization
    public var maxSequenceLength: Int {
        switch self {
        case .miniLML6V2:
            return 512 // Documentation says the sequence value is 256 however models expected input shape is 516.
        case .e5SmallV2:
            return 512
        }
    }
    
    /// Expected embedding dimension (for validation)
    public var expectedEmbeddingDimension: Int? {
        switch self {
        case .miniLML6V2:
            return 384  // Standard dimension for all-MiniLM-L6-v2
        case .e5SmallV2:
            return 384  // Standard dimension for e5-small-v2
        }
    }
    
    /// Human-readable description of the model
    public var description: String {
        switch self {
        case .miniLML6V2:
            return "all-MiniLM-L6-v2 (384-dimensional sentence embeddings)"
        case .e5SmallV2:
            return "e5-small-v2 (384-dimensional multilingual sentence embeddings)"
        }
    }

    /// Whether this model expects query/passage prefixes (E5-family models do)
    public var usesQueryPassagePrefixes: Bool {
        switch self {
        case .e5SmallV2:
            return true
        default:
            return false
        }
    }

    /// The prefix to apply to queries for this model (if any)
    public var queryPrefix: String {
        switch self {
        case .e5SmallV2:
            return "query: "
        default:
            return ""
        }
    }

    /// The prefix to apply to passages/documents for this model (if any)
    public var passagePrefix: String {
        switch self {
        case .e5SmallV2:
            return "passage: "
        default:
            return ""
        }
    }

    /// Apply the appropriate query prefix (no-op for models that don't require it)
    public func applyQueryPrefix(to text: String) -> String {
        return queryPrefix + text
    }

    /// Apply the appropriate passage/document prefix (no-op for models that don't require it)
    public func applyPassagePrefix(to text: String) -> String {
        return passagePrefix + text
    }
}
