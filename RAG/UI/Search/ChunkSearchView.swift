//
//  ChunkSearchView.swift
//  RAG
//
//  Created by Eric Collom on 12/12/25.
//

import SwiftUI

struct ChunkSearchView: View {
    @StateObject private var viewModel = ChunkSearchViewModel()
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Header
                SearchHeaderView(
                    viewModel: viewModel,
                    isSearchFieldFocused: $isSearchFieldFocused
                )
                
                // Results
                if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty && !viewModel.isLoading {
                    // No results state
                    ContentUnavailableView {
                        Label("No Results", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("No chunks found for '\(viewModel.searchQuery)'")
                    } actions: {
                        Button("Try Different Terms") {
                            isSearchFieldFocused = true
                        }
                    }
                } else if !viewModel.searchResults.isEmpty {
                    // Results list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // AI Response Section (if available)
                            if viewModel.isFoundationModelsAvailable {
                                AIResponseCard(viewModel: viewModel)
                            } else {
                                Text("Apple's Foundation Models is not available on your device")
                            }
                            
                            // Search Results
                            ForEach(Array(viewModel.searchResults.enumerated()), id: \.offset) { index, chunkWithScore in
                                ChunkResultCard(chunkWithScore: chunkWithScore, rank: index + 1)
                            }
                        }
                        .padding()
                    }
                } else if viewModel.searchQuery.isEmpty {
                    // Empty state
                    ContentUnavailableView {
                        Label("Search Chunks", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("Enter a search query to find relevant text chunks")
                    } actions: {
                        EmptyStateActionsView(viewModel: viewModel)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Chunk Search")
        }
    }
}

#Preview {
    ChunkSearchView()
}
