//
//  ChunkSearchViewModel.swift
//  RAG
//
//  Created by Eric Collom on 12/15/25.
//

import SwiftUI
import Combine
import FoundationModels
import Foundation

@MainActor
class ChunkSearchViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var selectedEmbedder: EmbedderType = .nlContextual
    @Published var isProcessingAI = false
    
    // Separate state for each embedder type
    @Published private var embedderStates: [EmbedderType: EmbedderState] = [:]
    
    private var ragServices: [EmbedderType: RAGService] = [:]
    private let foundationModelsManager = FoundationModelsSessionManager()
    
    // Computed properties that delegate to the current embedder state
    var searchQuery: String {
        get { currentState.searchQuery }
        set {
            ensureEmbedderState(for: selectedEmbedder)
            embedderStates[selectedEmbedder]!.searchQuery = newValue
            objectWillChange.send()
        }
    }
    
    var searchResults: [ChunkWithScore] {
        get { currentState.searchResults }
        set {
            ensureEmbedderState(for: selectedEmbedder)
            embedderStates[selectedEmbedder]!.searchResults = newValue
            objectWillChange.send()
        }
    }
    
    var aiResponse: String {
        get { currentState.aiResponse }
        set {
            ensureEmbedderState(for: selectedEmbedder)
            embedderStates[selectedEmbedder]!.aiResponse = newValue
            objectWillChange.send()
        }
    }
    
    var chunkCount: Int {
        get { currentState.chunkCount }
        set {
            ensureEmbedderState(for: selectedEmbedder)
            embedderStates[selectedEmbedder]!.chunkCount = newValue
            objectWillChange.send()
        }
    }
    
    private var currentState: EmbedderState {
        embedderStates[selectedEmbedder, default: EmbedderState()]
    }
    
    /// Ensures an embedder state exists for the given embedder type
    private func ensureEmbedderState(for embedderType: EmbedderType) {
        if embedderStates[embedderType] == nil {
            embedderStates[embedderType] = EmbedderState()
        }
    }
    
    var currentRAGService: RAGService {
        guard let service = ragServices[selectedEmbedder] else {
            fatalError("RAG service for \(selectedEmbedder.rawValue) not initialized. Call ensureCurrentRAGServiceInitialized() first.")
        }
        return service
    }
    
    /// Ensures the RAG service for the current embedder is properly initialized
    func ensureCurrentRAGServiceInitialized() async {
        if ragServices[selectedEmbedder] == nil {
            ragServices[selectedEmbedder] = await createRAGService(for: selectedEmbedder)
        }
    }
    
    init() {
        // Initialize states for all embedder types
        for embedderType in EmbedderType.allCases {
            embedderStates[embedderType] = EmbedderState()
        }
        
        Task {
            // Initialize with default embedder
            ragServices[.nlContextual] = await createRAGService(for: .nlContextual)
            await updateChunkCount()
        }
    }
    

    
    private func createRAGService(for embedderType: EmbedderType) async -> RAGService {
        do {
            switch embedderType {
            case .nlContextual:
                // Use the shared singleton for NL Contextual
                return RAGService.shared
                
            case .miniLM, .e5SmallV2:
                // Handle CoreML-based embedders generically
                guard let modelConfig = embedderType.mlTextEmbeddingModel else {
                    print("❌ No ML model configuration found for \(embedderType.rawValue)")
                    throw NSError(domain: "EmbedderError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No ML model configuration for \(embedderType.rawValue)"])
                }
                
                let embedder: CoreMLTextEmbedder
                
                // Check if this model requires a tokenizer folder
                if !modelConfig.tokenizationFolderName.isEmpty {
                    print("🔍 Setting up tokenizer for \(modelConfig.modelName)...")
                    do {
                        let tokenizerURL = try createTokenizerFolder(for: modelConfig)
                        print("✅ Created tokenizer folder for \(modelConfig.modelName) at: \(tokenizerURL.path)")
                        embedder = try await CoreMLTextEmbedder(modelConfig: modelConfig, tokenizerFolderURL: tokenizerURL)
                    } catch let tokenizerError {
                        print("❌ \(modelConfig.modelName) tokenizer setup failed: \(tokenizerError)")
                        throw tokenizerError
                    }
                } else {
                    // No tokenizer folder required
                    embedder = try await CoreMLTextEmbedder(modelConfig: modelConfig)
                }
                
                return try RAGService(embedder: embedder, dbPath: embedderType.databasePath)
            }
        } catch {
            print("Failed to create RAG service for \(embedderType): \(error)")
            print("Falling back to Apple NL Contextual embedder")
            // Fallback to shared service
            return RAGService.shared
        }
    }
    
    // Creates a temporary tokenizer folder structure for any model that requires tokenizer files
        private func createTokenizerFolder(for modelConfig: MLTextEmbeddingModel) throws -> URL {
            // Get the Documents directory to create a temporary folder
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let tokenizerFolderURL = documentsPath.appendingPathComponent("\(modelConfig.tokenizationFolderName)_tokenizer")
            
            // Create the directory if it doesn't exist
            try FileManager.default.createDirectory(at: tokenizerFolderURL, withIntermediateDirectories: true)
            
            // Check if files already exist (avoid recreating)
            let tokenizerJSONPath = tokenizerFolderURL.appendingPathComponent(modelConfig.tokenizerFileName)
            let tokenizerConfigPath = tokenizerFolderURL.appendingPathComponent(modelConfig.tokenizerConfigFileName)
            
            if FileManager.default.fileExists(atPath: tokenizerJSONPath.path) &&
                FileManager.default.fileExists(atPath: tokenizerConfigPath.path) {
                return tokenizerFolderURL
            }
            
            // Find the source files in the bundle
            guard let bundlePath = Bundle.main.resourcePath else {
                throw NSError(domain: "TokenizerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bundle path not found"])
            }
            
            let sourceTokenizerJSON = URL(fileURLWithPath: bundlePath).appendingPathComponent(modelConfig.bundleTokenizationFileName)
            let sourceTokenizerConfig = URL(fileURLWithPath: bundlePath).appendingPathComponent(modelConfig.bundleTokenizationConfigFileName)
            
            // Verify source files exist
            guard FileManager.default.fileExists(atPath: sourceTokenizerJSON.path) else {
                throw NSError(domain: "TokenizerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing \(modelConfig.bundleTokenizationFileName) in bundle"])
            }
            
            guard FileManager.default.fileExists(atPath: sourceTokenizerConfig.path) else {
                throw NSError(domain: "TokenizerError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing \(modelConfig.bundleTokenizationConfigFileName) in bundle"])
            }
            
            // Copy files with the expected names, removing existing files first if they exist
            if FileManager.default.fileExists(atPath: tokenizerJSONPath.path) {
                try FileManager.default.removeItem(at: tokenizerJSONPath)
            }
            if FileManager.default.fileExists(atPath: tokenizerConfigPath.path) {
                try FileManager.default.removeItem(at: tokenizerConfigPath)
            }
            
            try FileManager.default.copyItem(at: sourceTokenizerJSON, to: tokenizerJSONPath)
            try FileManager.default.copyItem(at: sourceTokenizerConfig, to: tokenizerConfigPath)
            
            print("✅ Created \(modelConfig.modelName) tokenizer folder with files:")
            print("   - \(tokenizerJSONPath.path)")
            print("   - \(tokenizerConfigPath.path)")
            
            return tokenizerFolderURL
        }
    
    func handleEmbedderChange(from oldEmbedder: EmbedderType, to newEmbedder: EmbedderType) async {
        guard newEmbedder != oldEmbedder else { return }
        
        isLoading = true
        
        print("Switching from \(oldEmbedder.displayName) to \(newEmbedder.displayName) embedder...")
        
        // Ensure the service for the new embedder is created and cached
        if ragServices[newEmbedder] == nil {
            ragServices[newEmbedder] = await createRAGService(for: newEmbedder)
        }
        
        // Update chunk count for new embedder if not already loaded
        if embedderStates[newEmbedder]?.chunkCount == 0 {
            await updateChunkCount(for: newEmbedder)
        }
        
        isLoading = false
        
        print("Successfully switched to \(newEmbedder.displayName) - \(chunkCount) chunks available")
        
        // Force UI update to reflect the new embedder's state
        await MainActor.run {
            objectWillChange.send()
        }
    }
    
    func switchEmbedder(to newEmbedder: EmbedderType) async {
        await handleEmbedderChange(from: selectedEmbedder, to: newEmbedder)
    }
    
    func performSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isLoading = true
        
        // Ensure the current RAG service is properly initialized
        await ensureCurrentRAGServiceInitialized()
        
        let results = await currentRAGService.performRAG(query: searchQuery)
        searchResults = results
        
        isLoading = false
    }
    
    func clearCurrentSearch() {
        searchQuery = ""
        searchResults = []
        aiResponse = ""
        // objectWillChange.send() is called by the setters above
    }
    
    // Helper method to force UI refresh when embedder state changes
    private func refreshUI() {
        objectWillChange.send()
    }
    
    // Debug method to check current state
    func debugCurrentState() -> String {
        let state = currentState
        return """
        Current Embedder: \(selectedEmbedder.rawValue)
        Query: '\(state.searchQuery)'
        Results: \(state.searchResults.count) items
        AI Response: '\(state.aiResponse.prefix(50))...'
        Chunk Count: \(state.chunkCount)
        """
    }
    
    func loadFridgePDF() async {
        isLoading = true
        do {
            await ensureCurrentRAGServiceInitialized()
            try await currentRAGService.loadFridgePDF() // English only
            await updateChunkCount()
            print("Fridge PDF loaded successfully (English only) for \(selectedEmbedder.rawValue)")
        } catch {
            print("Failed to load fridge PDF: \(error)")
        }
        isLoading = false
    }
    
    func clearDatabase() async {
        isLoading = true
        do {
            await ensureCurrentRAGServiceInitialized()
            try await currentRAGService.clearDatabase()
            await updateChunkCount()
            // Clear search results and AI response for current embedder
            searchResults = []
            aiResponse = ""
            print("Database cleared successfully for \(selectedEmbedder.rawValue)")
        } catch {
            print("Failed to clear database for \(selectedEmbedder.rawValue): \(error)")
        }
        isLoading = false
    }
    
    private func updateChunkCount() async {
        await updateChunkCount(for: selectedEmbedder)
    }
    
    private func updateChunkCount(for embedderType: EmbedderType) async {
        do {
            let service: RAGService
            if let existingService = ragServices[embedderType] {
                service = existingService
            } else {
                service = await createRAGService(for: embedderType)
                ragServices[embedderType] = service
            }
            let count = try await service.getChunkCount()
            
            // Update the chunk count in the appropriate embedder state
            await MainActor.run {
                ensureEmbedderState(for: embedderType)
                embedderStates[embedderType]!.chunkCount = count
                // Trigger UI update if this is for the currently selected embedder
                if embedderType == selectedEmbedder {
                    objectWillChange.send()
                }
            }
            
            print("Database for \(embedderType.rawValue) contains \(count) chunks")
        } catch {
            print("Failed to check database for \(embedderType.rawValue): \(error)")
            await MainActor.run {
                ensureEmbedderState(for: embedderType)
                embedderStates[embedderType]!.chunkCount = 0
                // Trigger UI update if this is for the currently selected embedder
                if embedderType == selectedEmbedder {
                    objectWillChange.send()
                }
            }
        }
    }
    
    // MARK: - AI Response Methods
    
    /// Generate an AI response based on search results
    func generateAIResponse() async {
        guard !searchResults.isEmpty else {
            aiResponse = ""
            return
        }
        
        isProcessingAI = true
        aiResponse = ""
        
        // Create context from search results
        let context = searchResults.prefix(5).map { chunk in
            "- \(chunk.text)"
        }.joined(separator: "\n")
        
        let prompt = """
        Based on the following relevant information, please answer the user's question: "\(searchQuery)"
        
        Relevant information:
        \(context)
        
        Please provide a helpful and accurate answer based on this information. If the information doesn't contain enough details to fully answer the question, mention what additional information might be needed.
        """
        
        let instructions = """
        You are a helpful assistant that answers questions based on provided context.
        Keep your responses clear, concise, and directly relevant to the user's question.
        Only use information from the provided context.
        If the context doesn't contain relevant information, say so.
        """
        
        do {
            let response = try await foundationModelsManager.processQuery(prompt, instructions: instructions)
            aiResponse = response
        } catch {
            print("AI response generation failed: \(error)")
            aiResponse = "Unable to generate AI response: \(error.localizedDescription)"
        }
        
        isProcessingAI = false
    }
    
    var isFoundationModelsAvailable: Bool {
        foundationModelsManager.isAvailable
    }
}

