//
//  RAGApp.swift
//  RAG
//
//  Created by Eric Collom on 12/8/25.
//

import SwiftUI

@main
struct RAGApp: App {
    
    var extractor: FileExtractionService = FileExtractionService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
