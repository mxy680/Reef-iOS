//
//  AnalyticsBarChartView.swift
//  Reef
//
//  Hand-built bar chart for daily study time.
//

import SwiftUI

struct AnalyticsBarChartView: View {
    let data: [(label: String, value: Double)]
    let colorScheme: ColorScheme
    var accentColor: Color = .deepTeal
    var highlightIndex: Int? = nil // Index to highlight (e.g., today)

    @State private var animatedProgress: CGFloat = 0

    private var maxValue: Double {
        max(data.map(\.value).max() ?? 1, 0.5)
    }

    /// Rounded ceiling for Y-axis (nearest 0.5 or 1)
    private var yAxisMax: Double {
        let raw = maxValue
        if raw <= 1 { return 1 }
        if raw <= 2 { return 2 }
        return ceil(raw)
    }

    private var yAxisLabels: [Double] {
        let step = yAxisMax <= 2 ? 0.5 : 1.0
        var labels: [Double] = []
        var v = 0.0
        while v <= yAxisMax {
            labels.append(v)
            v += step
        }
        return labels
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Y-axis labels
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(yAxisLabels.reversed(), id: \.self) { value in
                    Text(formatYLabel(value))
                        .font(.quicksand(10, weight: .medium))
                        .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                        .frame(height: value == yAxisLabels.last ? 14 : nil)
                    if value != yAxisLabels.first {
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(width: 28)
            .frame(maxHeight: .infinity)
            .padding(.bottom, 20) // Space for X-axis labels

            // Bars
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 4) {
                        Spacer(minLength: 0)

                        // Bar
                        RoundedRectangle(cornerRadius: 6)
                            .fill(barColor(for: index))
                            .frame(height: barHeight(for: item.value) * animatedProgress)
                            .frame(maxWidth: .infinity)

                        // X-axis label
                        Text(item.label)
                            .font(.quicksand(11, weight: .medium))
                            .foregroundColor(
                                index == highlightIndex
                                    ? Color.adaptiveText(for: colorScheme)
                                    : Color.adaptiveSecondaryText(for: colorScheme)
                            )
                            .frame(height: 16)
                    }
                }
            }
        }
        .frame(height: 160)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animatedProgress = 1
            }
        }
    }

    private func barColor(for index: Int) -> Color {
        if let hi = highlightIndex, index == hi {
            return .deepCoral
        }
        return accentColor
    }

    private func barHeight(for value: Double) -> CGFloat {
        guard yAxisMax > 0 else { return 0 }
        let maxBarHeight: CGFloat = 120
        return CGFloat(value / yAxisMax) * maxBarHeight
    }

    private func formatYLabel(_ value: Double) -> String {
        if value == 0 { return "0h" }
        if value == value.rounded() {
            return "\(Int(value))h"
        }
        return String(format: "%.1fh", value)
    }
}

#Preview {
    VStack {
        AnalyticsBarChartView(
            data: [
                ("Mon", 1.5), ("Tue", 2.0), ("Wed", 0.5),
                ("Thu", 1.8), ("Fri", 2.5), ("Sat", 0), ("Sun", 1.2)
            ],
            colorScheme: .light,
            highlightIndex: 4
        )
        .padding()
        .background(Color.white)

        AnalyticsBarChartView(
            data: [
                ("Mon", 1.5), ("Tue", 2.0), ("Wed", 0.5),
                ("Thu", 1.8), ("Fri", 2.5), ("Sat", 0), ("Sun", 1.2)
            ],
            colorScheme: .dark,
            highlightIndex: 4
        )
        .padding()
        .background(Color.warmDark)
    }
}
