//
//  ChunkResultCard.swift
//  RAG
//
//  Created by Eric Collom on 12/15/25.
//

import SwiftUI

struct ChunkResultCard: View {
    let chunkWithScore: ChunkWithScore
    let rank: Int
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with rank, score, and expand button
            HStack {
                HStack {
                    Text("#\(rank)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    // Similarity Score in green
                    Text("Score: \(chunkWithScore.score, specifier: "%.3f")")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                    
                    if let id = chunkWithScore.id {
                        Text("ID: \(id)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Text content
            Text(chunkWithScore.text)
                .font(.body)
                .lineLimit(isExpanded ? nil : 3)
                .multilineTextAlignment(.leading)
            
            // Metadata
            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Metadata")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("Similarity Score:")
                        Spacer()
                        Text("\(chunkWithScore.score, specifier: "%.6f")")
                            .foregroundStyle(.green)
                            .fontWeight(.medium)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("Embedding dimensions:")
                        Spacer()
                        Text("\(chunkWithScore.embedding.count)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    
                    Text("Text length: \(chunkWithScore.text.count) characters")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 0.5)
        )
    }
}
