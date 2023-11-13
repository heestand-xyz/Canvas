//
//  CanvasPolyGrid.swift
//  CanvasDemo
//
//  Created by Anton Heestand on 2021-03-01.
//

import SwiftUI
import CoreGraphicsExtensions

public struct CanvasPolyGrid: View {
    
    let canvasCoordinate: CCanvasCoordinate
    
    let size: CGFloat
    
    let count: Int
    
    public init(size: CGFloat, count: Int = 3, canvasCoordinate: CCanvasCoordinate) {
        self.size = size
        self.count = count
        self.canvasCoordinate = canvasCoordinate
    }
    
    var spacing: CGFloat {
        size * canvasCoordinate.scale
    }
    
    let fractions: [CGFloat] = [0.25, 1.0, 4.0, 16.0]
    
    public var body: some View {
        GeometryReader { geometry in
            let extraScale: CGFloat = max(2.0, 0.5 + geometry.size.height / geometry.size.width)
            ZStack {
                ForEach(fractions, id: \.self) { fraction in
                    if canvasCoordinate.scale > (0.25 / fraction) {
                        grid(at: fraction, extraScale: extraScale)
                            .opacity(Double((canvasCoordinate.scale - (0.25 / fraction)) * fraction))
                    }
                }
            }
            .canvasCoordinateRotationOffset(canvasCoordinate)
        }
        .drawingGroup()
    }
    
    func grid(at superScale: CGFloat = 1.0, lineWidth: CGFloat = .onePixel, extraScale: CGFloat = 2.0) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(0..<count), id: \.self) { i in
                    ForEach(-count(size: geo.size, at: superScale, extraScale: extraScale)...count(size: geo.size, at: superScale, extraScale: extraScale), id: \.self) { y in
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
    
    func count(size: CGSize, at superScale: CGFloat, extraScale: CGFloat) -> Int {
        let scaledSize: CGSize = (size / (spacing * superScale)) * extraScale
        guard !scaledSize.width.isNaN else { return 1 }
        return max(Int(scaledSize.width), Int(scaledSize.height))
    }
    
}

struct CanvasPolyGrid_Previews: PreviewProvider {
    static var previews: some View {
        CanvasPolyGrid(size: 100, canvasCoordinate: .zero)
    }
}
