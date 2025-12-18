//
//  ContentView.swift
//  RAG
//
//  Created by Eric Collom on 12/8/25.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        TabView {
            // Search tab with ChunkSearchView
            NavigationStack {
                ChunkSearchView()
                    .navigationTitle("Search")
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            
            // Embeddings tab with MLEmbeddingView
            NavigationStack {
                EmbedderView()
                    .navigationTitle("Embeddings")
            }
            .tabItem {
                Label("Embeddings", systemImage: "text.magnifyingglass")
            }
        }
    }
}

#Preview {
    ContentView()
}
