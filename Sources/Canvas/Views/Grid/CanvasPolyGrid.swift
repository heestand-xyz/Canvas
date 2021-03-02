//
//  CanvasPolyGrid.swift
//  CanvasDemo
//
//  Created by Anton Heestand on 2021-03-01.
//

import SwiftUI
import CoreGraphicsExtensions

public struct CanvasPolyGrid: View {
    
    let canvasCoordinate: CanvasCoordinate
    
    let size: CGFloat
    
    let count: Int
    
    public init(size: CGFloat, count: Int = 3, canvasCoordinate: CanvasCoordinate) {
        self.size = size
        self.count = count
        self.canvasCoordinate = canvasCoordinate
    }
    
    var spacing: CGFloat {
        size * canvasCoordinate.scale
    }
    
    let extraScale: CGFloat = 2.0
    
    let fractions: [CGFloat] = [0.25, 1.0, 4.0, 16.0]
    
    public var body: some View {
        ZStack {
            ForEach(fractions, id: \.self) { fraction in
                if canvasCoordinate.scale > (0.25 / fraction) {
                    grid(at: fraction)
                        .opacity(Double((canvasCoordinate.scale - (0.25 / fraction)) * fraction))
                }
            }
        }
        .canvasCoordinateRotationOffset(canvasCoordinate)
    }
    
    func grid(at superScale: CGFloat = 1.0, lineWidth: CGFloat = .onePixel) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(0..<count) { i in
                    ForEach(-count(size: geo.size, at: superScale)...count(size: geo.size, at: superScale), id: \.self) { y in
                        Rectangle()
                            .frame(height: lineWidth)
                            .frame(width: geo.size.width * extraScale * 2.0)
                            .offset(x: -geo.size.width * extraScale)
                            .offset(y: (spacing * superScale) * CGFloat(y))
                            .offset(y: CGFloat(Int(rotatedOffsetX(at: i) / (spacing * superScale))) * (spacing * superScale) * -1.0)
                            .offset(x: rotatedOffsetY(at: i) * -1.0)
                            .rotationEffect(angle(at: i), anchor: .topLeading)
                    }
                }
            }
        }
    }
    
    func rotatedOffsetX(at index: Int) -> CGFloat {
        canvasCoordinate.rotatedOffset.x * cos(radians(at: index) + .pi * 0.5)
            + canvasCoordinate.rotatedOffset.y * sin(radians(at: index) + .pi * 0.5)
    }
    
    func rotatedOffsetY(at index: Int) -> CGFloat {
        canvasCoordinate.rotatedOffset.x * cos(radians(at: index))
            + canvasCoordinate.rotatedOffset.y * sin(radians(at: index))
    }
    
    func radians(at index: Int) -> CGFloat {
        CGFloat(angle(at: index).radians)
    }
    
    func angle(at index: Int) -> Angle {
        Angle(radians: Double(fraction(at: index) * .pi * 2))
    }
    
    func fraction(at index: Int) -> CGFloat {
        CGFloat(index) / CGFloat(count)
    }
    
    func count(size: CGSize, at superScale: CGFloat) -> Int {
        let scaledSize: CGSize = (size / (spacing * superScale)) * extraScale
        return max(Int(scaledSize.width), Int(scaledSize.height))
    }
    
}

struct CanvasPolyGrid_Previews: PreviewProvider {
    static var previews: some View {
        CanvasPolyGrid(size: 100, canvasCoordinate: .zero)
    }
}
