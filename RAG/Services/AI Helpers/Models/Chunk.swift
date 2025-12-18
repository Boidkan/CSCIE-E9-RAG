//
//  Chunk.swift
//  RAG
//
//  Created by Eric Collom on 12/10/25.
//

import GRDB
import Foundation

struct Chunk: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var text: String // Todo change this to be generic later
    var embedding: [Double]
}

struct ChunkWithScore {
    let chunk: Chunk
    let score: Double
    
    var id: Int64? { chunk.id }
    var text: String { chunk.text }
    var embedding: [Double] { chunk.embedding }
}
