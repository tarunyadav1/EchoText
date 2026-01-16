import SwiftUI

/// Real-time waveform visualization for audio level
struct WaveformView: View {
    let level: Float
    let barCount: Int
    let barSpacing: CGFloat
    let animationDuration: Double

    @State private var barHeights: [CGFloat] = []

    init(
        level: Float,
        barCount: Int = 5,
        barSpacing: CGFloat = 3,
        animationDuration: Double = 0.1
    ) {
        self.level = level
        self.barCount = barCount
        self.barSpacing = barSpacing
        self.animationDuration = animationDuration
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    WaveformBar(
                        height: calculateHeight(for: index, maxHeight: geometry.size.height),
                        maxHeight: geometry.size.height
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: level) { newLevel in
            updateBarHeights(for: newLevel)
        }
        .onAppear {
            initializeBarHeights()
        }
    }

    private func initializeBarHeights() {
        barHeights = Array(repeating: 0.2, count: barCount)
    }

    private func updateBarHeights(for level: Float) {
        withAnimation(.easeOut(duration: animationDuration)) {
            // Create a wave pattern based on the level
            let baseHeight = CGFloat(level)
            barHeights = (0..<barCount).map { index in
                // Create variation for wave effect
                let variation = sin(Double(index) * .pi / Double(barCount - 1))
                return max(0.1, min(1.0, baseHeight * CGFloat(0.5 + variation * 0.5)))
            }
        }
    }

    private func calculateHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
        guard index < barHeights.count else { return maxHeight * 0.2 }
        return maxHeight * barHeights[index]
    }
}

// MARK: - Waveform Bar

struct WaveformBar: View {
    let height: CGFloat
    let maxHeight: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [.red, .orange]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(height: height)
            .animation(.easeOut(duration: 0.1), value: height)
    }
}

// MARK: - Alternative Waveform Styles

/// Circular waveform for compact display
struct CircularWaveformView: View {
    let level: Float

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)

            // Active level
            Circle()
                .trim(from: 0, to: CGFloat(level))
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [.red, .orange]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.1), value: level)

            // Center indicator
            Circle()
                .fill(level > 0.1 ? Color.red : Color.gray)
                .frame(width: 8, height: 8)
                .scaleEffect(1.0 + CGFloat(level) * 0.5)
                .animation(.easeOut(duration: 0.1), value: level)
        }
    }
}

/// Oscilloscope-style waveform
struct OscilloscopeView: View {
    let samples: [Float]
    let lineWidth: CGFloat

    init(samples: [Float] = [], lineWidth: CGFloat = 2) {
        self.samples = samples
        self.lineWidth = lineWidth
    }

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !samples.isEmpty else {
                    // Draw flat line when no samples
                    path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
                    return
                }

                let stepX = geometry.size.width / CGFloat(samples.count - 1)
                let midY = geometry.size.height / 2

                path.move(to: CGPoint(x: 0, y: midY + CGFloat(samples[0]) * midY))

                for (index, sample) in samples.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = midY + CGFloat(sample) * midY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [.green, .yellow, .red]),
                    startPoint: .bottom,
                    endPoint: .top
                ),
                lineWidth: lineWidth
            )
        }
    }
}

// MARK: - Preview
#Preview("Bar Waveform") {
    VStack(spacing: 20) {
        WaveformView(level: 0.3)
            .frame(width: 80, height: 40)
            .background(Color.black.opacity(0.1))

        WaveformView(level: 0.7)
            .frame(width: 80, height: 40)
            .background(Color.black.opacity(0.1))

        WaveformView(level: 1.0)
            .frame(width: 80, height: 40)
            .background(Color.black.opacity(0.1))
    }
    .padding()
}

#Preview("Circular Waveform") {
    HStack(spacing: 20) {
        CircularWaveformView(level: 0.3)
            .frame(width: 50, height: 50)

        CircularWaveformView(level: 0.7)
            .frame(width: 50, height: 50)

        CircularWaveformView(level: 1.0)
            .frame(width: 50, height: 50)
    }
    .padding()
}
