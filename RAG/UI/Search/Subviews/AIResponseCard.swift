//
//  AIResponseCard.swift
//  RAG
//
//  Created by Eric Collom on 12/15/25.
//

import SwiftUI

struct AIResponseCard: View {
    @ObservedObject var viewModel: ChunkSearchViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack {
                    Image(systemName: "brain")
                        .foregroundStyle(.blue)
                    
                    Text("AI Response")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                if !viewModel.aiResponse.isEmpty {
                    Button("Generate New Response") {
                        Task {
                            await viewModel.generateAIResponse()
                        }
                    }
                    .disabled(viewModel.isProcessingAI)
                }
            }
            
            // Response Content
            if viewModel.isProcessingAI {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                    
                    Text("Generating response...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                
            } else if !viewModel.aiResponse.isEmpty {
                Text(viewModel.aiResponse)
                    .font(.body)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .padding()
                    .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.blue.opacity(0.2), lineWidth: 1)
                    )
                
            } else {
                // Action buttons to generate response
                VStack(spacing: 8) {
                    Text("Generate an AI-powered response based on your search results")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack {
                        Button("Generate Response") {
                            Task {
                                await viewModel.generateAIResponse()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.2), lineWidth: 1)
                )
            }
            
            // Footer info
            if !viewModel.aiResponse.isEmpty {
                HStack {
                    Text("Based on \(min(5, viewModel.searchResults.count)) most relevant search results")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                    
                    Text("(\(viewModel.selectedEmbedder.rawValue))")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }
        }
    }
}

#Preview {
    AIResponseCard(viewModel: ChunkSearchViewModel())
}
