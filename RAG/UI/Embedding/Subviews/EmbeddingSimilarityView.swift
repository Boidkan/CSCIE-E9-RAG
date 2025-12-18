import SwiftUI

struct EmbeddingSimilarityView: View {
    let similarities: [(String, Double)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Embedding Similarity")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(Array(similarities.enumerated()), id: \.offset) { _, similarity in
                HStack {
                    Text(similarity.0)
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.4f", similarity.1))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(similarity.1 > 0.8 ? .green : similarity.1 > 0.5 ? .orange : .red)
                }
                .padding()
                .background(Color(systemGray6))
                .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
}