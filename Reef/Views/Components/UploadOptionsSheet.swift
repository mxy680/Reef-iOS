//
//  UploadOptionsSheet.swift
//  Reef
//
//  Bottom sheet for upload options including assignment mode toggle
//

import SwiftUI

struct UploadOptionsSheet: View {
    @Binding var isPresented: Bool
    @State private var assignmentModeEnabled: Bool = true
    let urls: [URL]
    let onUpload: (Bool) -> Void

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            // Centered popup card
            VStack(spacing: 16) {
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
                        .toggleStyle(SwitchToggleStyle(tint: .vibrantTeal))
                        .labelsHidden()
                }

                // Processing time note
                if assignmentModeEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("1-2 min processing")
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
                            .padding(.vertical, 11)
                            .background(Color(white: 0.94))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                            .padding(.vertical, 11)
                            .background(Color.vibrantTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .frame(width: 320)
            .background(Color.lightGrayBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: assignmentModeEnabled)
    }
}

#Preview {
    UploadOptionsSheet(
        isPresented: .constant(true),
        urls: [URL(fileURLWithPath: "/test.pdf")],
        onUpload: { _ in }
    )
}
