//
//  RecognitionFeedbackView.swift
//  Reef
//
//  Displays handwriting recognition results
//

import SwiftUI

/// View that displays handwriting recognition results
struct RecognitionFeedbackView: View {
    let result: RecognitionResult
    let onDismiss: () -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.vibrantTeal)
                    Text("Recognition")
                        .font(.headline)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }

                if isExpanded {
                    Divider()

                    // Recognized text
                    if !result.text.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Text")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(result.text)
                                .font(.body)
                        }
                    }

                    // LaTeX (if available)
                    if let latex = result.latex, !latex.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Math (LaTeX)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(latex)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.oceanMid)
                        }
                    }

                    // Stroke count
                    Text("\(result.strokeCount) strokes processed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Above the toolbar
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        RecognitionFeedbackView(
            result: RecognitionResult(
                text: "Hello World",
                latex: "x^2 + y^2 = z^2",
                jiix: "{}",
                strokeCount: 5
            ),
            onDismiss: {}
        )
    }
}
