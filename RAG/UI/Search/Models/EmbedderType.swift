//
//  EmbedderType.swift
//  RAG
//
//  Created by Eric Collom on 12/16/25.
//

enum EmbedderType: String, CaseIterable, Identifiable {
    case nlContextual = "Apple NL"
    case miniLM = "MiniLM"
    case e5SmallV2 = "E5-Small-V2"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .nlContextual:
            return "Apple NL Contextual"
        case .miniLM:
            return "MiniLM (all-MiniLM-L6-v2)"
        case .e5SmallV2:
            return "E5-Small-V2"
        }
    }
    
    var description: String {
        switch self {
        case .nlContextual:
            return "Apple's built-in Natural Language framework"
        case .miniLM:
            return "High-quality sentence transformer model"
        case .e5SmallV2:
            return "Multilingual text embedding model optimized for retrieval"
        }
    }
    
    /// Maps the embedder type to its corresponding MLTextEmbeddingModel configuration
    /// Returns nil for embedder types that don't use CoreML models (like nlContextual)
    var mlTextEmbeddingModel: MLTextEmbeddingModel? {
        switch self {
        case .nlContextual:
            return nil  // Uses Apple's built-in NL framework, not CoreML
        case .miniLM:
            return .miniLML6V2
        case .e5SmallV2:
            return .e5SmallV2
        }
    }
    
    /// Database path for this embedder type
    var databasePath: String {
        switch self {
        case .nlContextual:
            return "db_nlContextual.sqlite"  // Default shared DB path
        case .miniLM:
            return "db_miniLM.sqlite"
        case .e5SmallV2:
            return "db_e5SmallV2.sqlite"
        }
    }
}
