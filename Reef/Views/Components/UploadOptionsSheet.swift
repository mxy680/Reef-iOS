//
//  UploadOptionsSheet.swift
//  Reef
//
//  Bottom sheet for upload options including assignment mode toggle
//

import SwiftUI
import PDFKit

struct UploadOptionsSheet: View {
    @Binding var isPresented: Bool
    @State private var assignmentModeEnabled: Bool = true
    @State private var totalPages: Int = 0
    let urls: [URL]
    let onUpload: (Bool) -> Void

    /// Estimated processing time for Hetzner CPU-only server with cold start.
    /// Formula: 30s cold start + 25s/doc base + 8s/page (layout detection + extraction).
    private var estimatedTimeString: String {
        guard totalPages > 0 else { return "Estimating..." }
        let totalSeconds = 30 + 25 * urls.count + 8 * totalPages
        let minutes = Int((Double(totalSeconds) / 60.0).rounded())
        return "~\(max(minutes, 1)) min processing"
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            // Centered popup card
            VStack(spacing: 20) {
                // Header
                Text("Upload \(urls.count) \(urls.count == 1 ? "file" : "files")")
                    .font(.quicksand(16, weight: .semiBold))
                    .foregroundColor(Color(white: 0.2))

                // Assignment mode toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Assignment Mode")
                            .font(.quicksand(14, weight: .medium))
                            .foregroundColor(Color(white: 0.2))

                        Text("Extract problems individually")
                            .font(.quicksand(11, weight: .regular))
                            .foregroundColor(Color(white: 0.5))
                    }

                    Spacer()

                    Toggle("", isOn: $assignmentModeEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .deepTeal))
                        .labelsHidden()
                }

                // Processing time estimate
                if assignmentModeEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(estimatedTimeString)
                            .font(.quicksand(10, weight: .regular))
                    }
                    .foregroundColor(Color(white: 0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                }

                // Buttons
                HStack(spacing: 10) {
                    Button {
                        isPresented = false
                    } label: {
                        Text("Cancel")
                            .font(.quicksand(14, weight: .medium))
                            .foregroundColor(Color(white: 0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(white: 0.94))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        isPresented = false
                        onUpload(assignmentModeEnabled)
                    } label: {
                        Text("Upload")
                            .font(.quicksand(14, weight: .semiBold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.deepTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
            .frame(width: 360)
            .background(Color.blushWhite)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.15), radius: 32, x: 0, y: 12)
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: assignmentModeEnabled)
        .onAppear {
            totalPages = urls.reduce(0) { count, url in
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                return count + (PDFDocument(url: url)?.pageCount ?? 0)
            }
        }
    }
}

#Preview {
    UploadOptionsSheet(
        isPresented: .constant(true),
        urls: [URL(fileURLWithPath: "/test.pdf")],
        onUpload: { _ in }
    )
}
