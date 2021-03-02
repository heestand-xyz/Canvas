//
//  CanvasGrid.swift
//  CanvasDemo
//
//  Created by Anton Heestand on 2021-03-01.
//

import SwiftUI
import Canvas
import CoreGraphicsExtensions

public struct CanvasGrid: View {
    
    let canvasCoordinate: CanvasCoordinate
    
    let size: CGFloat
    
    public init(size: CGFloat, canvasCoordinate: CanvasCoordinate) {
        self.size = size
        self.canvasCoordinate = canvasCoordinate
    }
    
    var spacing: CGFloat {
        size * canvasCoordinate.scale
    }
    
    let extraScale: CGFloat = 2.0
    
    let fractions: [CGFloat] = [0.1, 1.0, 10.0, 100.0]
    
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
                ForEach(-count(size: geo.size, at: superScale)...count(size: geo.size, at: superScale), id: \.self) { x in
                    Rectangle()
                        .frame(width: lineWidth)
                        .frame(height: geo.size.height * extraScale * 2.0)
                        .offset(y: -geo.size.height * extraScale)
                        .offset(x: (spacing * superScale) * CGFloat(x))
                        .offset(x: CGFloat(Int(canvasCoordinate.rotatedOffset.x / (spacing * superScale))) * (spacing * superScale) * -1.0)
                        .offset(y: canvasCoordinate.rotatedOffset.y * -1.0)
                }
                ForEach(-count(size: geo.size, at: superScale)...count(size: geo.size, at: superScale), id: \.self) { y in
                    Rectangle()
                        .frame(height: lineWidth)
                        .frame(width: geo.size.width * extraScale * 2.0)
                        .offset(x: -geo.size.width * extraScale)
                        .offset(y: (spacing * superScale) * CGFloat(y))
                        .offset(y: CGFloat(Int(canvasCoordinate.rotatedOffset.y / (spacing * superScale))) * (spacing * superScale) * -1.0)
                        .offset(x: canvasCoordinate.rotatedOffset.x * -1.0)
                }
            }
        }
    }
    
    func count(size: CGSize, at superScale: CGFloat) -> Int {
        let scaledSize: CGSize = (size / (spacing * superScale)) * extraScale
        return max(Int(scaledSize.width), Int(scaledSize.height))
    }
    
}

struct CanvasGrid_Previews: PreviewProvider {
    static var previews: some View {
        CanvasGrid(size: 100, canvasCoordinate: .zero)
    }
}
