import SwiftUI
import UIKit

/// 九宫格手势解锁组件：3x3 点阵，拖动连线，回调输出点序号数组（0-8，按连接顺序）。
struct PatternLockView: View {
    var minPoints: Int = 4
    var onComplete: ([Int]) -> Void
    var onError: (() -> Void)? = nil

    @State private var selected: [Int] = []
    @State private var finger: CGPoint?
    @State private var isError = false
    @State private var shake = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let step = side / 3.0
            let centers = makeCenters(step: step)

            ZStack {
                // 已连接点的连线
                if !selected.isEmpty {
                    Path { path in
                        path.move(to: centers[selected[0]])
                        for i in selected.dropFirst() {
                            path.addLine(to: centers[i])
                        }
                        if let finger {
                            path.addLine(to: finger)
                        }
                    }
                    .stroke(
                        isError ? Color.red : Color.blue,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                }

                // 3x3 圆点
                ForEach(0..<9, id: \.self) { i in
                    let isSel = selected.contains(i)
                    Circle()
                        .fill(isSel ? (isError ? Color.red : Color.blue) : Color.gray.opacity(0.25))
                        .frame(width: isSel ? 42 : 28, height: isSel ? 42 : 28)
                        .overlay(
                            Circle().stroke(
                                isSel ? (isError ? Color.red : Color.blue) : Color.gray.opacity(0.6),
                                lineWidth: 2
                            )
                        )
                        .scaleEffect(isSel ? 1.0 : 0.9)
                        .position(centers[i])
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSel)
                }
            }
            .frame(width: side, height: side)
            .offset(x: shake ? -8 : 0)
            .animation(.easeInOut(duration: 0.08).repeatCount(shake ? 3 : 0), value: shake)
            .contentShape(Rectangle())
            .gesture(dragGesture(centers: centers))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func makeCenters(step: CGFloat) -> [CGPoint] {
        (0..<9).map { i in
            let row = i / 3
            let col = i % 3
            return CGPoint(x: step * (CGFloat(col) + 0.5), y: step * (CGFloat(row) + 0.5))
        }
    }

    private func dragGesture(centers: [CGPoint]) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isError else { return }
                finger = value.location
                if let idx = nearest(to: value.location, centers: centers, radius: 45),
                   !selected.contains(idx) {
                    selected.append(idx)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            .onEnded { _ in
                finger = nil
                let pattern = selected
                selected = []
                if pattern.count >= minPoints {
                    onComplete(pattern)
                } else {
                    triggerError()
                    onError?()
                }
            }
    }

    private func nearest(to point: CGPoint, centers: [CGPoint], radius: CGFloat) -> Int? {
        var best: Int?
        var bestDist = radius
        for (i, c) in centers.enumerated() {
            let d = hypot(point.x - c.x, point.y - c.y)
            if d < bestDist {
                bestDist = d
                best = i
            }
        }
        return best
    }

    private func triggerError() {
        isError = true
        shake = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isError = false
                shake = false
            }
        }
    }
}
