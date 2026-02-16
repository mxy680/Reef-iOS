//
//  AnalyticsDonutView.swift
//  Reef
//
//  Donut/ring chart for coaching frequency breakdown.
//

import SwiftUI

struct AnalyticsDonutView: View {
    let segments: [(value: Double, color: Color)]
    let centerText: String
    let centerLabel: String
    let colorScheme: ColorScheme
    var lineWidth: CGFloat = 16
    var size: CGFloat = 100

    @State private var animatedProgress: CGFloat = 0

    private var total: Double {
        segments.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Color.adaptiveSecondaryText(for: colorScheme).opacity(0.1),
                    lineWidth: lineWidth
                )
                .frame(width: size, height: size)

            // Segment rings
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                let (start, end) = trimRange(for: index)
                Circle()
                    .trim(from: start, to: start + (end - start) * animatedProgress)
                    .stroke(
                        segment.color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
            }

            // Center label
            VStack(spacing: 1) {
                Text(centerText)
                    .font(.dynaPuff(22, weight: .bold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                Text(centerLabel)
                    .font(.quicksand(10, weight: .medium))
                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
            }
        }
        .frame(width: size + lineWidth, height: size + lineWidth)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animatedProgress = 1
            }
        }
    }

    private func trimRange(for index: Int) -> (CGFloat, CGFloat) {
        guard total > 0 else { return (0, 0) }

        var start: Double = 0
        for i in 0..<index {
            start += segments[i].value / total
        }

        let end = start + segments[index].value / total
        // Small gap between segments
        let gap: Double = segments.count > 1 ? 0.01 : 0
        return (CGFloat(start + gap / 2), CGFloat(end - gap / 2))
    }
}

#Preview {
    HStack(spacing: 40) {
        AnalyticsDonutView(
            segments: [
                (18, Color.deepCoral),
                (5, Color.seafoam)
            ],
            centerText: "23",
            centerLabel: "total",
            colorScheme: .light
        )

        AnalyticsDonutView(
            segments: [
                (18, Color.deepCoral),
                (5, Color.seafoam)
            ],
            centerText: "23",
            centerLabel: "total",
            colorScheme: .dark
        )
        .background(Color.warmDark)
    }
    .padding(40)
}
