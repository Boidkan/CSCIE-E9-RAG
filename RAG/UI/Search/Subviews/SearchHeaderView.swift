//
//  SearchHeaderView.swift
//  RAG
//
//  Created by Eric Collom on 12/15/25.
//

import SwiftUI

struct SearchHeaderView: View {
    @ObservedObject var viewModel: ChunkSearchViewModel
    @FocusState.Binding var isSearchFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Embedder Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Embedding Model")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                Picker("Embedder", selection: $viewModel.selectedEmbedder) {
                    ForEach(EmbedderType.allCases) { embedder in
                        Text(embedder.displayName)
                            .tag(embedder)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.selectedEmbedder) { oldValue, newValue in
                    Task {
                        await viewModel.handleEmbedderChange(from: oldValue, to: newValue)
                    }
                }
                
                Text(viewModel.selectedEmbedder.description)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.leading)
            }
            
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search chunks...", text: $viewModel.searchQuery)
                    .focused($isSearchFieldFocused)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task {
                            await viewModel.performSearch()
                        }
                    }
                
                if !viewModel.searchQuery.isEmpty {
                    Button("Clear") {
                        viewModel.clearCurrentSearch()
                        isSearchFieldFocused = false
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            
            // Search Button
            Button {
                Task {
                    await viewModel.performSearch()
                }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text("Search")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(viewModel.searchQuery.isEmpty ? .gray.opacity(0.3) : .blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.searchQuery.isEmpty || viewModel.isLoading)
            
            // Database Status
            HStack {
                Image(systemName: "database")
                    .foregroundStyle(.secondary)
                
                if viewModel.isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.6)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Database: \(viewModel.chunkCount) chunks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                Text("(\(viewModel.selectedEmbedder.rawValue))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}

#Preview {
    @FocusState var isFocused: Bool
    
    SearchHeaderView(
        viewModel: ChunkSearchViewModel(),
        isSearchFieldFocused: $isFocused
    )
}