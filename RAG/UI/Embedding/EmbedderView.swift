import SwiftUI

struct EmbedderView: View {
    @StateObject private var viewModel = EmbedderViewModel()

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Text Embedding Comparison")
                    .font(.title2)
                    .bold()
                
                Text("Generate embeddings using different models")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Input section
            EmbeddingInputSection(
                inputText: $viewModel.inputText,
                selectedEmbeddingType: $viewModel.selectedEmbeddingType,
                onGenerate: viewModel.generateEmbeddings,
                isGenerating: viewModel.isGenerating
            )
            
            // Results section
            if !viewModel.embeddingResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(viewModel.embeddingResults.enumerated()), id: \.offset) { index, result in
                            EmbeddingResultCard(result: result)
                        }
                    }
                    .padding(.horizontal)
                }
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }
}

struct CompleteSentenceEmbedderView_Previews: PreviewProvider {
    static var previews: some View {
        EmbedderView()
    }
}
