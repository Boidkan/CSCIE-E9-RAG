//
//  EmbedderState.swift
//  RAG
//
//  Created by Eric Collom on 12/16/25.
//

// State container for each embedding type
struct EmbedderState {
    var searchQuery: String = ""
    var searchResults: [ChunkWithScore] = []
    var aiResponse: String = ""
    var chunkCount: Int = 0
}
