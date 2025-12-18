import SwiftUI

struct EmbeddingInputSection: View {
    @Binding var inputText: String
    @Binding var selectedEmbeddingType: EmbeddingType
    let onGenerate: () -> Void
    let isGenerating: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Model selection picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Model(s):")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Picker("Embedding Model", selection: $selectedEmbeddingType) {
                    ForEach(EmbeddingType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            TextField("Enter sentence to embed", text: $inputText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
            
            // Generate button
            if isGenerating {
                VStack {
                    ProgressView()
                    Text("Generating embeddings...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Generate Embeddings") {
                    onGenerate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal)
    }
}