import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct EmbeddingResultCard: View {
    let result: EmbeddingResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with model info
            HStack {
                VStack(alignment: .leading) {
                    Text(result.type.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 16) {
                        Label("\(result.dimensionality)D", systemImage: "cube")
                        Label(String(format: "%.3fs", result.duration), systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Embedding preview (first few values)
            let previewValues = Array(result.embedding.prefix(6))
            Text("[\(previewValues.map { String(format: "%.4f", $0) }.joined(separator: ", "))\(result.embedding.count > 6 ? ", ..." : "")]")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            
            // Full embedding (expandable)
            if isExpanded {
                ScrollView {
                    Text(result.embedding.map { String(format: "%.6f", $0) }.joined(separator: ", "))
                        .font(.caption)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 150)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Action buttons
            HStack {
                Button("Copy Values") {
                    copyToPasteboard(result.embedding.map { String($0) }.joined(separator: ","))
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func copyToPasteboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(text, forType: .string)
        #endif
    }
}
