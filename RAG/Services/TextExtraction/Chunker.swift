//
//  IntelligentChunker.swift
//  RAG
//
//  Created by Eric Collom on 12/9/25.
//

import NaturalLanguage

class Chunker {
    let chunkSize: Int
    let overlap: Int
    
    private let separators = ["\n\n", "\n", ". ", " ", ""]
    
    init(chunkSize: Int = 1000, overlap: Int = 200) {
        self.chunkSize = chunkSize
        self.overlap = overlap
    }
    
    func chunk(_ text: String) -> [String] {
        print("📚 Chunking Process Started:")
        print("   Input text length: \(text.count) characters")
        print("   Target chunk size: \(chunkSize) characters")
        print("   Overlap: \(overlap) characters")
        
        let chunks = chunk(text, separators: separators)
        
        print("   Created \(chunks.count) chunks")
        
        // Calculate and display chunk statistics
        if !chunks.isEmpty {
            let lengths = chunks.map { $0.count }
            let minLength = lengths.min() ?? 0
            let maxLength = lengths.max() ?? 0
            let avgLength = lengths.reduce(0, +) / lengths.count
            
            print("   📊 Chunk Statistics:")
            print("      Min length: \(minLength) characters")
            print("      Max length: \(maxLength) characters") 
            print("      Avg length: \(avgLength) characters")
        }
        
        for (index, chunk) in chunks.enumerated() {
            let preview = String(chunk.prefix(60)) + (chunk.count > 60 ? "..." : "")
            print("   Chunk \(index + 1): \(chunk.count) chars - \"\(preview)\"")
        }
        
        return chunks
    }
    
    func chunk(_ text: String, separators: [String]) -> [String] {
        
        var finalChunks: [String] = []
        var separator = separators.last ?? ""
        var newSeparators = separators
        
        // Pick a separator to use
        for (index, sep) in separators.enumerated() {
            if sep == "" || text.contains(sep) {
                separator = sep
                newSeparators = Array(separators.dropFirst(index + 1))
                break
            }
        }
        
        let initialSplits = separator.isEmpty ? text.map { String($0) } : text.components(separatedBy: separator)
        
        var currentDoc = ""
        
        for split in initialSplits {
            let nextSegment = split + separator
            
            if currentDoc.count + nextSegment.count > chunkSize {
                if !currentDoc.isEmpty {
                    finalChunks.append(currentDoc.trimmingCharacters(in: .whitespacesAndNewlines))
                    
                    if overlap > 0 && currentDoc.count > overlap {
                        let overlapIndex = currentDoc.index(currentDoc.endIndex, offsetBy: -overlap)
                        currentDoc = String(currentDoc[overlapIndex...])
                    } else {
                        currentDoc = ""
                    }
                }
                
                if nextSegment.count > chunkSize && !newSeparators.isEmpty {
                    let subChunks = chunk(nextSegment, separators: newSeparators)
                    finalChunks.append(contentsOf: subChunks)
                } else {
                    currentDoc += nextSegment
                }
            } else {
                currentDoc += nextSegment
            }
        }
        
        if !currentDoc.isEmpty {
            finalChunks.append(currentDoc.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return finalChunks
    }
}
