import Foundation

enum EmbeddingType: String, CaseIterable {
    case miniLML6V2 = "MiniLM-L6-v2"
    case e5SmallV2 = "E5-Small-v2"
    case nlContextual = "NL Contextual"
    case all = "All Models"
    
    /// Maps to MLTextEmbeddingModel for CoreML models
    var mlModel: MLTextEmbeddingModel? {
        switch self {
        case .miniLML6V2:
            return .miniLML6V2
        case .e5SmallV2:
            return .e5SmallV2
        case .nlContextual, .all:
            return nil
        }
    }
}

struct EmbeddingResult {
    let type: EmbeddingType
    let embedding: [Double]
    let dimensionality: Int
    let duration: TimeInterval
}
