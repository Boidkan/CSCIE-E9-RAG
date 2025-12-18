//
//  EmptyStateActionsView.swift
//  RAG
//
//  Created by Eric Collom on 12/15/25.
//

import SwiftUI

struct EmptyStateActionsView: View {
    @ObservedObject var viewModel: ChunkSearchViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Text("Load data for \(viewModel.selectedEmbedder.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Load Fridge PDF (English Only)") {
                    Task {
                        await viewModel.loadFridgePDF()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }
            
            Button("Clear Database") {
                Task {
                    await viewModel.clearDatabase()
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
}

#Preview {
    EmptyStateActionsView(viewModel: ChunkSearchViewModel())
}