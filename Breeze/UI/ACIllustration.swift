import SwiftUI

struct ACIllustration: View {
    let isOn: Bool
    let isWindFree: Bool
    let setpoint: Int
    let accent: Color

    var body: some View {
        VStack(spacing: 2) {
            unit
                .frame(width: 210, height: 56)
            airflow
                .frame(width: 200, height: 54)
                .opacity(isOn ? 1 : 0)
                .animation(.easeInOut(duration: 0.6), value: isOn)
        }
        .accessibilityElement()
        .accessibilityLabel(isOn ? Text("Air conditioner on") : Text("Air conditioner off"))
    }

    private var unit: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [.white, Color(white: 0.84)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 6)

            // Small holes on the WindFree panel
            Canvas { context, size in
                let spacing: CGFloat = 5
                for x in stride(from: 18, to: size.width - 18, by: spacing) {
                    for y in stride(from: 12, to: size.height - 18, by: spacing) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                                     with: .color(.black.opacity(0.10)))
                    }
                }
            }
            .padding(.trailing, 46)

            Text(isOn ? "\(setpoint)" : "")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.8), radius: 3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 10)
                .padding(.trailing, 18)

            Capsule()
                .fill(Color.black.opacity(isOn && !isWindFree ? 0.75 : 0.35))
                .frame(height: 5)
                .padding(.horizontal, 20)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 7)
        }
    }

    private var airflow: some View {
        TimelineView(.animation(paused: !isOn)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                if isWindFree {
                    drawParticles(in: &context, size: size, time: time)
                } else {
                    drawStreams(in: &context, size: size, time: time)
                }
            }
        }
    }

    private func drawStreams(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let count = 12
        for index in 0..<count {
            let progress = Double(index) / Double(count - 1)
            let baseX = size.width * (0.08 + 0.84 * progress)
            var path = Path()
            path.move(to: CGPoint(x: baseX, y: 0))
            for y in stride(from: 0.0, through: size.height, by: 2) {
                let sway = sin(y * 0.11 - time * 4 + Double(index) * 0.7) * 2.6 * (y / size.height)
                path.addLine(to: CGPoint(x: baseX + sway + (progress - 0.5) * y * 0.25, y: y))
            }
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [accent.opacity(0.55), accent.opacity(0)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
                ),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
            )
        }
    }

    private func drawParticles(in context: inout GraphicsContext, size: CGSize, time: Double) {
        for index in 0..<90 {
            let seed = Double(index) * 12.9898
            let x = (sin(seed) * 0.5 + 0.5) * size.width
            let speed = 6 + (cos(seed * 1.7) * 0.5 + 0.5) * 8
            let y = (time * speed + Double(index) * 7).truncatingRemainder(dividingBy: size.height)
            let fade = 1 - y / size.height
            let drift = sin(time * 0.8 + seed) * 3
            context.fill(
                Path(ellipseIn: CGRect(x: x + drift, y: y, width: 2, height: 2)),
                with: .color(accent.opacity(0.9 * fade))
            )
        }
    }
}
