import SwiftUI

struct CompletionAnimation: View {
    let title: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burst = false
    @State private var checked = false
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(blue.opacity(0.07)).frame(width: 49, height: 49)
                Circle().trim(from: 0, to: checked ? 1 : 0).stroke(blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 49, height: 49).rotationEffect(.degrees(-90))
                Image(systemName: "checkmark").font(.system(size: 23, weight: .bold)).foregroundStyle(blue)
                    .scaleEffect(checked ? 1 : 0.35).opacity(checked ? 1 : 0)
                if !reduceMotion {
                    ForEach(0..<14) { index in
                        let angle = Double(index) * .pi * 2 / 14
                        RoundedRectangle(cornerRadius: index.isMultiple(of: 2) ? 3 : 1)
                            .fill(index.isMultiple(of: 2) ? paper : blue)
                            .frame(width: index.isMultiple(of: 3) ? 5 : 3, height: 7)
                            .rotationEffect(.degrees(burst ? Double(index * 47 + 100) : 0))
                            .offset(x: burst ? cos(angle) * 57 : 0, y: burst ? sin(angle) * 43 - 10 : 0)
                            .opacity(burst ? 0 : 1)
                    }
                }
            }.frame(width: 66, height: 66)
            VStack(alignment: .leading, spacing: 5) {
                Text("Done. A little more room.").font(.system(size: 13, weight: .bold, design: .rounded))
                Text(title).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(12).frame(width: 285).background(canvas, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(outline))
            .shadow(color: blue.opacity(0.13), radius: 16, y: 5)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore).accessibilityLabel("Completed: \(title)")
            .onAppear {
                withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.45, dampingFraction: 0.6)) { checked = true }
                if !reduceMotion { withAnimation(.easeOut(duration: 1.2)) { burst = true } }
            }
    }
}
