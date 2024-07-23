import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    Circle()
                        .stroke(
                            Color.blue.opacity(0.5),
                            lineWidth: geometry.size.width / 10
                        )
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.blue,
                            style: StrokeStyle(
                                lineWidth: geometry.size.width / 10,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut, value: progress)
                }
            }
        }
    }
}

#Preview {
    VStack {
        CircularProgressView(progress: 0.25).frame(width: 100, height: 100)
    }
}
