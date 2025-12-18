//
//  FoundationModelsSessionManager.swift
//  RAG
//
//  Created by Eric Collom on 12/15/25.
//

import Foundation
import FoundationModels
import Combine

/// A comprehensive session manager for Apple's on-device Foundation Models
@MainActor
class FoundationModelsSessionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAvailable: Bool = false
    @Published var isProcessing: Bool = false
    @Published var currentResponse: String = ""
    @Published var errorMessage: String?
    @Published var modelStatus: String = "Checking availability..."
    
    // MARK: - Private Properties
    
    private let model = SystemLanguageModel.default
    private var currentSession: LanguageModelSession?
    
    // Default instructions for the model
    private let defaultInstructions = """
        You are a helpful AI assistant that provides accurate, concise responses.
        Keep responses clear and focused on the user's specific question.
        If you don't know something, say so rather than guessing.
        """
    
    // MARK: - Initialization
    
    init() {
        checkModelAvailability()
    }
    
    // MARK: - Public Methods
    
    /// Process a query and return the model's response
    func processQuery(_ query: String, instructions: String? = nil) async throws -> String {
        guard isAvailable else {
            throw FoundationModelsError.modelNotAvailable
        }
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FoundationModelsError.emptyQuery
        }
        
        isProcessing = true
        errorMessage = nil
        currentResponse = ""
        
        defer {
            isProcessing = false
        }
        
        do {
            // Create session with instructions
            let sessionInstructions = instructions ?? defaultInstructions
            let session = LanguageModelSession(instructions: sessionInstructions)
            currentSession = session
            
            // Generate response
            let response = try await session.respond(to: query)
            let result = response.content
            
            currentResponse = result
            return result
            
        } catch {
            errorMessage = "Failed to process query: \(error.localizedDescription)"
            throw FoundationModelsError.processingFailed(error)
        }
    }
    
    /// Check if the model is currently responding
    var isResponding: Bool {
        return currentSession?.isResponding ?? false
    }
    
    // MARK: - Private Methods
    
    private func checkModelAvailability() {
        switch model.availability {
        case .available:
            isAvailable = true
            modelStatus = "Model is available and ready"
            
        case .unavailable(.deviceNotEligible):
            isAvailable = false
            modelStatus = "Device not eligible for Apple Intelligence"
            
        case .unavailable(.appleIntelligenceNotEnabled):
            isAvailable = false
            modelStatus = "Please enable Apple Intelligence in Settings"
            
        case .unavailable(.modelNotReady):
            isAvailable = false
            modelStatus = "Model is downloading or not ready"
            
        case .unavailable(let other):
            isAvailable = false
            modelStatus = "Model unavailable: \(other)"
        }
    }
    
    /// Refresh model availability status
    func refreshAvailability() {
        checkModelAvailability()
    }
}

// MARK: - Conversational Session

/// A wrapper for multi-turn conversations
class ConversationalSession {
    private let session: LanguageModelSession
    private weak var manager: FoundationModelsSessionManager?
    
    init(session: LanguageModelSession, manager: FoundationModelsSessionManager) {
        self.session = session
        self.manager = manager
    }
    
    /// Send a message in the conversation
    func sendMessage(_ message: String) async throws -> String {
        guard let manager = manager else {
            throw FoundationModelsError.sessionInvalid
        }
        
        await MainActor.run {
            manager.isProcessing = true
            manager.errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                manager.isProcessing = false
            }
        }
        
        do {
            let response = try await session.respond(to: message)
            let result = response.content
            
            await MainActor.run {
                manager.currentResponse = result
            }
            
            return result
            
        } catch {
            await MainActor.run {
                manager.errorMessage = "Failed to send message: \(error.localizedDescription)"
            }
            throw FoundationModelsError.processingFailed(error)
        }
    }
    
    /// Stream a response in the conversation
    func streamMessage(_ message: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard let manager = manager else {
                    continuation.finish(throwing: FoundationModelsError.sessionInvalid)
                    return
                }
                
                await MainActor.run {
                    manager.isProcessing = true
                    manager.errorMessage = nil
                    manager.currentResponse = ""
                }
                
                do {
                    let stream = session.streamResponse(to: message)
                    
                    for try await partialResponse in stream {
                        let content = partialResponse.content
                        await MainActor.run {
                            manager.currentResponse = content
                        }
                        continuation.yield(content)
                    }
                    
                    continuation.finish()
                    
                } catch {
                    await MainActor.run {
                        manager.errorMessage = "Failed to stream message: \(error.localizedDescription)"
                    }
                    continuation.finish(throwing: FoundationModelsError.processingFailed(error))
                }
                
                await MainActor.run {
                    manager.isProcessing = false
                }
            }
        }
    }
    
    /// Check if the session is currently responding
    var isResponding: Bool {
        return session.isResponding
    }
}

// MARK: - Error Handling

enum FoundationModelsError: LocalizedError {
    case modelNotAvailable
    case emptyQuery
    case processingFailed(Error)
    case sessionInvalid
    
    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "Foundation Models is not available on this device"
        case .emptyQuery:
            return "Query cannot be empty"
        case .processingFailed(let error):
            return "Processing failed: \(error.localizedDescription)"
        case .sessionInvalid:
            return "Conversational session is no longer valid"
        }
    }
}
