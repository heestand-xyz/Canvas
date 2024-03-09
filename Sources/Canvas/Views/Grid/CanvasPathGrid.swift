//
//  CanvasPathGrid.swift
//  CanvasDemo
//
//  Created by Anton Heestand on 2021-03-01.
//

import SwiftUI
import CoreGraphicsExtensions

public struct CanvasPathGrid: View {
    
    let canvasCoordinate: CCanvasCoordinate
    
    let size: CGFloat
    
    public init(size: CGFloat, canvasCoordinate: CCanvasCoordinate) {
        self.size = size
        self.canvasCoordinate = canvasCoordinate
    }
    
    var spacing: CGFloat {
        size * canvasCoordinate.scale
    }
    
    let fractions: [CGFloat] = [0.1, 1.0, 10.0]
    
    public var body: some View {
        ZStack {
            ForEach(fractions, id: \.self) { fraction in
                if canvasCoordinate.scale > (0.25 / fraction) {
                    grid(at: fraction)
                        .opacity(Double((canvasCoordinate.scale - (0.25 / fraction)) * fraction))
                }
            }
        }
    }
    
    func grid(at superScale: CGFloat = 1.0, lineWidth: CGFloat = .onePixel) -> some View {
        GeometryReader { geo in
            Path { path in
                for x in 0...xCount(size: geo.size, at: superScale) {
                    let offset: CGFloat = canvasCoordinate.offset.x.truncatingRemainder(dividingBy: spacing * superScale) + CGFloat(x) * spacing * superScale
                    path.move(to: CGPoint(x: offset, y: 0.0))
                    path.addLine(to: CGPoint(x: offset, y: geo.size.height))
                }
                for y in 0...yCount(size: geo.size, at: superScale) {
                    let offset: CGFloat = canvasCoordinate.offset.y.truncatingRemainder(dividingBy: spacing * superScale) + CGFloat(y) * spacing * superScale
                    path.move(to: CGPoint(x: 0.0, y: offset))
                    path.addLine(to: CGPoint(x: geo.size.width, y: offset))
                }
            }
            .stroke()
        }
    }
    
    func xCount(size: CGSize, at superScale: CGFloat) -> Int {
        let scaledSize: CGFloat = size.width / (spacing * superScale)
        return Int(ceil(scaledSize))
    }
    
    func yCount(size: CGSize, at superScale: CGFloat) -> Int {
        let scaledSize: CGFloat = size.height / (spacing * superScale)
        return Int(ceil(scaledSize))
    }
}

struct CanvasPathGrid_Previews: PreviewProvider {
    static var previews: some View {
        CanvasPathGrid(size: 100, canvasCoordinate: .zero)
    }
}
