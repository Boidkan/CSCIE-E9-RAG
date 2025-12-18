import Foundation
import SwiftUI
import Combine

@MainActor
class EmbedderViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var embeddingResults: [EmbeddingResult] = []
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedEmbeddingType: EmbeddingType = .all
    
    private var coreMLEmbedders: [MLTextEmbeddingModel: CoreMLTextEmbedder] = [:]
    
    init() {
        Task {
            await initializeCoreMLEmbedders()
        }
    }
    
    // MARK: - Public Methods
    
    func generateEmbeddings() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "Input text cannot be empty."
            return
        }
        
        clearError()
        startGenerating()

        Task {
            await performEmbeddingGeneration(for: text)
        }
    }
    

    // MARK: - Private Methods
    
    private func initializeCoreMLEmbedders() async {
        // Initialize all available CoreML models
        for model in [MLTextEmbeddingModel.miniLML6V2, MLTextEmbeddingModel.e5SmallV2] {
            do {
                let embedder = try await CoreMLTextEmbedder(modelConfig: model)
                Task { @MainActor in
                    coreMLEmbedders[model] = embedder
                }
                
            } catch {
                print("Failed to initialize \(model.description): \(error.localizedDescription)")
            }
        }
    }
    
    private func clearError() {
        errorMessage = nil
    }
    
    private func startGenerating() {
        isGenerating = true
        embeddingResults.removeAll()
    }
    
    private func finishGenerating(with results: [EmbeddingResult]) {
        embeddingResults = results
        isGenerating = false
    }
    
    private func handleError(_ error: Error) {
        errorMessage = "Failed to generate embeddings: \(error.localizedDescription)"
        isGenerating = false
    }
    
    private func performEmbeddingGeneration(for text: String) async {
        var results: [EmbeddingResult] = []
        
        do {
            switch selectedEmbeddingType {
            case .miniLML6V2:
                if let result = try await generateCoreMLEmbedding(for: text, model: .miniLML6V2, type: .miniLML6V2) {
                    results.append(result)
                }
            case .e5SmallV2:
                if let result = try await generateCoreMLEmbedding(for: text, model: .e5SmallV2, type: .e5SmallV2) {
                    results.append(result)
                }
            case .nlContextual:
                if let nlResult = try await generateNLContextualEmbedding(for: text) {
                    results.append(nlResult)
                }
            case .all:
                // Generate all available embeddings
                if let miniLMResult = try await generateCoreMLEmbedding(for: text, model: .miniLML6V2, type: .miniLML6V2) {
                    results.append(miniLMResult)
                }
                if let e5Result = try await generateCoreMLEmbedding(for: text, model: .e5SmallV2, type: .e5SmallV2) {
                    results.append(e5Result)
                }
                if let nlResult = try await generateNLContextualEmbedding(for: text) {
                    results.append(nlResult)
                }
            }
            
            finishGenerating(with: results)
        } catch {
            handleError(error)
        }
    }
    
    private func generateCoreMLEmbedding(for text: String, model: MLTextEmbeddingModel, type: EmbeddingType) async throws -> EmbeddingResult? {
        guard let embedder = coreMLEmbedders[model] else { return nil }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let embedding = try await embedder.embed(text: text)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        return EmbeddingResult(
            type: type,
            embedding: embedding,
            dimensionality: embedding.count,
            duration: duration
        )
    }
    
    private func generateNLContextualEmbedding(for text: String) async throws -> EmbeddingResult? {
        let startTime = CFAbsoluteTimeGetCurrent()
        guard let embedding = try await EmbeddingService.shared.embed(text: text) else {
            return nil
        }
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        return EmbeddingResult(
            type: .nlContextual,
            embedding: embedding,
            dimensionality: embedding.count,
            duration: duration
        )
    }
}
