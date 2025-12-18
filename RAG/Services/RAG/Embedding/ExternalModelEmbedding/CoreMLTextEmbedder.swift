//
//  FoundationModelsSessionManager.swift
//  RAG
//
//  Created by Eric Collom on 12/13/25.
//

import Foundation
import CoreML
import NaturalLanguage
import Models
import Tokenizers
import Hub

/// A generic text embedding service that works with any CoreML text embedding model.
/// This class provides high-quality sentence embeddings for semantic similarity tasks.
final class CoreMLTextEmbedder: EmbeddingProvider {
    
    // MARK: - Properties
    
    private let model: MLModel
    private let tokenizer: any Tokenizer
    private let modelConfig: MLTextEmbeddingModel
    
    /// The model name for this embedder
    var modelName: String { modelConfig.modelName }
    
    /// The maximum sequence length for this embedder
    var maxSequenceLength: Int { modelConfig.maxSequenceLength }
    
    /// The expected embedding dimension for this embedder
    var expectedEmbeddingDimension: Int? { modelConfig.expectedEmbeddingDimension }
    
    // MARK: - Initialization
    
    /// Initialize the text embedder with a specific model configuration.
    /// - Parameters:
    ///   - modelConfig: The model configuration containing all necessary parameters
    ///   - compiledModelURL: Optional URL to the compiled CoreML model. If nil, will search in bundle.
    ///   - tokenizerFolderURL: Optional URL to the tokenizer folder. If nil, will search in bundle.
    ///   - computeUnits: The compute units to use for model inference (default: .cpuAndGPU)
    /// - Throws: EmbeddingError if model loading fails
    init(
        modelConfig: MLTextEmbeddingModel,
        compiledModelURL: URL? = nil,
        tokenizerFolderURL: URL? = nil,
        computeUnits: MLComputeUnits = .cpuAndGPU
    ) async throws {
        self.modelConfig = modelConfig
        
        // Get or find the compiled model URL
        let modelURL: URL
        if let providedModelURL = compiledModelURL {
            modelURL = providedModelURL
        } else {
            modelURL = try CoreMLTextEmbedder.findModelInBundle(modelName: modelConfig.modelName)
        }
        
        // Get or find the tokenizer folder URL
        let tokenizerURL: URL
        if let providedTokenizerURL = tokenizerFolderURL {
            tokenizerURL = providedTokenizerURL
        } else {
            // Try to find tokenizer folder in bundle
            tokenizerURL = try EmbeddingModelLoader.tokenizerFolderURL(
                resourceName: modelConfig.tokenizationFolderName
            )
        }
        
        do {
            // Validate tokenizer files exist
            try EmbeddingModelLoader.validateTokenizerFiles(in: tokenizerURL)
            
            // Load the CoreML model directly
            let mlConfig = MLModelConfiguration()
            mlConfig.computeUnits = computeUnits
            
            // Check if the model URL is a compiled model (.mlmodelc) or uncompiled (.mlmodel)
            if modelURL.pathExtension == "mlmodelc" {
                // For compiled models, use contentsOf:configuration:
                self.model = try MLModel(contentsOf: modelURL, configuration: mlConfig)
            } else {
                // For uncompiled models, compile first then load
                let compiledURL = try await MLModel.compileModel(at: modelURL)
                self.model = try MLModel(contentsOf: compiledURL, configuration: mlConfig)
            }
            
            // Load the tokenizer using the same approach as EmbeddingModelLoader
            self.tokenizer = try await AutoTokenizer.from(modelFolder: tokenizerURL)
            
            print("✅ Successfully loaded model: \(modelConfig.modelName)")
        } catch {
            if error is TokenizerError {
                throw EmbeddingError.tokenizationFailed
            } else {
                throw EmbeddingError.modelLoadingFailed(error)
            }
        }
    }
    
    /// Comprehensive model discovery in the bundle
    /// - Parameter modelName: Base name of the model (without extension)
    /// - Returns: URL to the model file
    /// - Throws: EmbeddingError.modelNotFound with detailed information
    static private func findModelInBundle(modelName: String) throws -> URL {
        // Try the exact name first
        let primaryNames = [modelName]
        
        // Then try common variations
        let fallbackNames = [
            modelName.replacingOccurrences(of: "_", with: "-"),
            modelName.replacingOccurrences(of: "-", with: "_"),
            modelName.lowercased(),
            modelName.uppercased()
        ]
        
        let allNames = primaryNames + fallbackNames
        let fileTypes = ["mlmodelc", "mlmodel"]
        
        // Try each combination
        for name in allNames {
            for type in fileTypes {
                if let url = Bundle.main.url(forResource: name, withExtension: type) {
                    return url
                }
            }
        }
        
        // If not found, provide detailed error information
        let availableModels = CoreMLTextEmbedder.getAllModelFilesInBundle()
        var errorMessage = "Model '\(modelName)' not found in bundle."
        
        if !availableModels.isEmpty {
            errorMessage += " Available models: \(availableModels.joined(separator: ", "))"
        } else {
            errorMessage += " No .mlmodel or .mlmodelc files found in bundle."
        }
        
        print("❌ \(errorMessage)")
        throw EmbeddingError.modelNotFound
    }
    
    /// Get all model files in the bundle
    /// - Returns: Array of model file names found in the bundle
    static private func getAllModelFilesInBundle() -> [String] {
        guard let bundlePath = Bundle.main.resourcePath else { return [] }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
            return contents.filter { $0.hasSuffix(".mlmodel") || $0.hasSuffix(".mlmodelc") }
                         .sorted()
        } catch {
            print("Error reading bundle contents: \(error)")
            return []
        }
    }
    
    // MARK: - Public Methods
    
    /// Generate embedding for the given text using the loaded CoreML model.
    /// - Parameter text: Input text to embed
    /// - Returns: Embedding vector (dimension depends on the model)
    /// - Throws: EmbeddingError for various failure cases
    func embed(text: String) async throws -> [Double] {
        // Check text length
        guard text.count <= 10000 else {
            throw EmbeddingError.textTooLong(text.count)
        }
        
        do {
            // Tokenize the input text
            let tokens = tokenizer.encode(text: text)
            
            // Prepare input for CoreML model
            // Most embedding models expect input_ids and attention_mask
            let inputIds = tokens.map { Int32($0) }
            let maxLength = min(inputIds.count, maxSequenceLength)
            let truncatedTokens = Array(inputIds.prefix(maxLength))
            
            if truncatedTokens.count < tokens.count {
                print("✂️ Truncated: \(tokens.count) → \(truncatedTokens.count) tokens")
            }
            
            // Pad or truncate to expected length if needed
            var paddedTokens = truncatedTokens
            if paddedTokens.count < maxSequenceLength {
                let padding = Array(repeating: Int32(0), count: maxSequenceLength - paddedTokens.count)
                paddedTokens.append(contentsOf: padding)
//                print("📏 Padded: \(truncatedTokens.count) → \(paddedTokens.count) tokens (added \(padding.count) padding tokens)")
            }
            
            // Create attention mask (1 for real tokens, 0 for padding)
            let attentionMask = Array(0..<maxSequenceLength).map { $0 < truncatedTokens.count ? Int32(1) : Int32(0) }
            
            // Create MLMultiArray inputs
            let inputIdsArray = try MLMultiArray(shape: [1, NSNumber(value: maxSequenceLength)], dataType: .int32)
            let attentionMaskArray = try MLMultiArray(shape: [1, NSNumber(value: maxSequenceLength)], dataType: .int32)
            
            // Fill the arrays
            for i in 0..<paddedTokens.count {
                inputIdsArray[i] = NSNumber(value: paddedTokens[i])
            }
            for i in 0..<attentionMask.count {
                attentionMaskArray[i] = NSNumber(value: attentionMask[i])
            }
            
            // Prepare input dictionary for CoreML model
            // Note: The actual input names may vary by model, but these are common
            let inputFeatures = [
                "input_ids": MLFeatureValue(multiArray: inputIdsArray),
                "attention_mask": MLFeatureValue(multiArray: attentionMaskArray)
            ]
            
            let inputProvider = try MLDictionaryFeatureProvider(dictionary: inputFeatures)
            
            // Run inference
            let output = try await model.prediction(from: inputProvider)
            
            // Extract embedding from output
            // Common output names for embedding models include "pooler_output", "embeddings", or "last_hidden_state"
            var embedding: [Double]?
            var selectedOutputName: String?
            var selectedPoolingDescription: String?
            
            // Try different possible output names
            let possibleOutputNames = ["pooler_output", "embeddings", "last_hidden_state", "sentence_embedding"]
            
            for outputName in possibleOutputNames {
                if let featureValue = output.featureValue(for: outputName),
                   let multiArray = featureValue.multiArrayValue {
                    
                    // If it's a pooled output (2D: [batch_size, embedding_dim])
                    if multiArray.shape.count == 2 {
                        let embeddingSize = multiArray.shape[1].intValue
                        embedding = (0..<embeddingSize).map { i in
                            Double(multiArray[i].floatValue)
                        }
                        selectedOutputName = outputName
                        selectedPoolingDescription = "pooled sentence output (2D)"
                        break
                    }
                    // If it's sequence output (3D: [batch_size, seq_len, hidden_size]), use mean pooling
                    else if multiArray.shape.count == 3 {
                        let seqLen = multiArray.shape[1].intValue
                        let hiddenSize = multiArray.shape[2].intValue
                        
                        // Mean pooling across sequence length
                        var pooled = Array(repeating: 0.0, count: hiddenSize)
                        var validTokenCount = 0
                        
                        for seqIdx in 0..<seqLen {
                            if attentionMask[seqIdx] == 1 {
                                validTokenCount += 1
                                for hiddenIdx in 0..<hiddenSize {
                                    let index = seqIdx * hiddenSize + hiddenIdx
                                    pooled[hiddenIdx] += Double(multiArray[index].floatValue)
                                }
                            }
                        }
                        
                        // Average by valid token count
                        if validTokenCount > 0 {
                            embedding = pooled.map { $0 / Double(validTokenCount) }
                        }
                        selectedOutputName = outputName
                        selectedPoolingDescription = "mean pooling over sequence (3D last_hidden_state)"
                        break
                    }
                }
            }
            
            guard let finalEmbedding = embedding else {
                print("❌ Could not find embedding output in model. Available outputs: \(output.featureNames)")
                throw EmbeddingError.invalidOutput
            }
            
            return finalEmbedding
        } catch {
            print("❌ Embedding generation failed: \(error)")
            if error is EmbeddingError {
                throw error
            } else {
                throw EmbeddingError.predictionFailed(error)
            }
        }
    }
}

